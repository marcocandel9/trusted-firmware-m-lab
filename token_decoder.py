import sys
from pprint import pprint 


# ---------------------------------------------------------------------------
# CBOR rule
#
#   intestation byte  = TTTIIIII
#                           header_info  (5 LSb)  -> where to find argument
#                           header_type  (3 MSb)   -> 
#
# header_info 0..23 -> info is the argument
# header_info 24/25/26/27 -> argument is in the following 1/2/4/8 byte
#
# type determinates what arguments means:
#   integers   -> the value
#   string -> byte length
#   array    -> the number of elements that follows
#   mappe    -> the noumber of COUPLES t hat follows
#   tag      -> tag number
#
# ---------------------------------------------------------------------------

# ---- CBOR MAJOR TYPES ----- #
# TYPE 0: UNSIGNED INT -> ARG: UINT VALUE
# TYPE 1: NEGATIVE INTEGER -> ARG: -1 - ARG
# TYPE 2: BYTE STRING -> ARG: LENGTH
# TYPE 3: TEXT STRING(UTF-8) -> ARG: LENGTH
# TYPE 4: ARRAY -> NUMBER OF ELEM
# TYPE 5: MAP -> NUMBER OF COUPLES
# TYPE 6: TAG -> NUMBER OF TAG
# TYPE 7: SIMPLE/FLOAT -> SPECIAL CODE
# ----------------------------- #

UINT,NINT,BSTR,TSTR,ARRAY,MAP,TAG,SIMPLE = range(8)

# --- from now on header_info == type, arg == info
def read_intestation(b,i):
    first_b = b[i]
    header_info = first_b & 0x1F #getting 5 LSb
    header_type = first_b >> 5

    # pointing to the next byte
    i += 1
    if header_info < 24:
        arg = header_info
    elif header_info == 24:
        arg = b[i]; i += 1
    elif header_info == 25:
        arg = int.from_bytes(b[i:i+2],"big"); i += 2
    elif header_info == 26:
        arg = int.from_bytes(b[i:i+4], "big"); i+= 4
    elif header_info == 27:
        arg = int.from_bytes(b[i:i+8], "big"); i+= 8
    else:
        raise ValueError(f"header_info {header_info} not handled at offset {i-1}")

    return header_type,arg,i

def read_element(b, i):

    # Saving initial byte offset in order to rebuild CBOR raw data of the element.
    start = i

    header_type, arg, i = read_intestation(b, i)

    if header_type == UINT:
        return {
            "type": "UINT",
            "raw": b[start:i].hex(),
            "value": arg
        }, i

    elif header_type == NINT:
        return {
            "type": "NINT",
            "raw": b[start:i].hex(),
            "value": -1 - arg
        }, i

    elif header_type == BSTR:
        end = i + arg

        return {
            "type": "BSTR",
            "raw": b[start:end].hex(),
            "value": b[i:end]
        }, end

    elif header_type == TSTR:
        end = i + arg

        return {
            "type": "TSTR",
            "raw": b[start:end].hex(),
            "value": b[i:end].decode("utf-8")
        }, end

    elif header_type == ARRAY:
        out = []

        for _ in range(arg):
            element, i = read_element(b, i)
            out.append(element)

        return {
            "type": "ARRAY",
            "length": arg,
            "raw": b[start:i].hex(),
            "value": out
        }, i

    elif header_type == MAP:
        entries = []

        for _ in range(arg):
            key, i = read_element(b, i)
            value, i = read_element(b, i)

            entries.append({
                "key": key,
                "value": value
            })

        return {
            "type": "MAP",
            "length": arg,
            "raw": b[start:i].hex(),
            "value": entries
        }, i

    elif header_type == TAG:
        tagged_element, i = read_element(b, i)

        return {
            "type": "TAG",
            "tag": arg,
            "meaning": CBOR_TAGS.get(arg, "unknown"),
            "raw": b[start:i].hex(),
            "value": tagged_element
        }, i

    raise ValueError(f"header type {header_type} not handled")

# ------------------ CCDDL (Coincise Data Def. language[RFC8610] of PSA TOKENS ---------------
# Those are the keys of the MAP of claims of the PSA tokens
PSA_CLAIMS = {
    -75000: "profile_id",
    -75001: "client_id",
    -75002: "security_lifecycle",
    -75003: "implementation_id",
    -75004: "boot_seed",
    -75005: "hardware_version",
    -75006: "software_components",
    -75007: "no_software_measurements",
    -75008: "nonce",
    -75009: "instance_id",
    -75010: "origination",
}

PSA_SW_COMPONENT_CLAIMS = {
    1: "measurement_type",
    2: "measurement_value",
    4: "version",
    5: "signer_id",
    6: "measurement_description",
}

CBOR_TAGS = {
        18:"COSE_Sign1"
        }

# 
# in : CBOR parsed dictionary
# out: CBOR COSEsign1 annoted dictionary, if compatible (checks if the first tag is COSE_sign1), payload dict 
def annotate_cosesign1(cbor_root):

    if not isinstance(cbor_root, dict):
        return None

    if cbor_root.get("type") != "TAG":
        return None

    if cbor_root.get("tag") != 18:
        return None

    cose_array = cbor_root["value"]

    if cose_array.get("type") != "ARRAY":
        return None

    elements = cose_array["value"]

    if len(elements) != 4:
        return None

    protected = elements[0]
    unprotected = elements[1]
    payload = elements[2]
    signature = elements[3]

    protected["COSE_sign1_field"] = "protected"
    unprotected["COSE_sign1_field"] = "unprotected"
    payload["COSE_sign1_field"] = "payload"
    signature["COSE_sign1_field"] = "signature"

    return cbor_root,payload

def build_payload(payload):

    if payload.get("type") != "BSTR":
        raise ValueError(
            "payload builder failed: payload type is not BSTR"
        )

    payload_bytes = payload["value"]

    decoded_payload, end = read_element(payload_bytes, 0)

    if end != len(payload_bytes):
        raise ValueError(
            f"Payload CBOR not fully consumed: "
            f"{end}/{len(payload_bytes)} bytes"
        )

    payload["decoded"] = decoded_payload

    return decoded_payload

# in: decoded payload
# out: (in-place: decoded payload incremented with psa claim annotation, returns decoded payload ref)
def annotate_psa(decoded_payload):
    if decoded_payload.get("type") != "MAP": raise ValueError(f"annotate_psa error: decoded payload type is {decoded_payload.get("type")}, not a CBOR MAP.")
    psa_claims = decoded_payload["value"]# list -> psa_claim value dict -> key dict: value dict
    for elem in psa_claims:
        elem_key = elem["key"]
        annotate_psa_key(elem_key)
    return decoded_payload


# -  checks if key dict "value" is in PSA CLAIMS, if it is, returns the value string.
def annotate_psa_key(key):
    if key["type"] in ("UINT", "NINT"):
        claim_id = key["value"]
        print("PSA KEY:", claim_id)
        meaning = PSA_CLAIMS.get(claim_id)
        if meaning is not None:
            key["psa_claim_meaning"] = meaning
    return key

def annotate_software_components(decoded_payload):
    if decoded_payload.get("type") != "MAP":
        raise ValueError(
            f"annotate_sw_components error: decoded payload type is "
            f"{decoded_payload.get('type')}, not a CBOR MAP."
        )
    psa_claims = decoded_payload["value"]
    software_components = None
    # Find software_components PSA claim
    for psa_claim in psa_claims:
        psa_claim_key = psa_claim["key"]
        if psa_claim_key.get("psa_claim_meaning") == "software_components":
            sw_array = psa_claim["value"]
            if sw_array.get("type") != "ARRAY":
                raise ValueError(
                    "software_components value is not a CBOR ARRAY"
                )
            software_components = sw_array["value"]
            break
    if software_components is None:
        raise ValueError(
            "software_components PSA claim not found"
        )
    component_num = 1
    for sw in software_components:
        if sw.get("type") != "MAP":
            raise ValueError(
                f"software component {component_num} is "
                f"{sw.get('type')}, not a CBOR MAP"
            )
        sw["software_component_num"] = component_num
        sw_claims = sw["value"]
        for sw_claim in sw_claims:
            key = sw_claim["key"]
            if key.get("type") not in ("UINT", "NINT"):
                raise ValueError(
                    f"software component claim key is "
                    f"{key.get('type')}, expected integer"
                )
            claim_id = key["value"]
            psa_sw_claim = PSA_SW_COMPONENT_CLAIMS.get(claim_id)
            if psa_sw_claim is None:
                raise ValueError(
                    f"annotate_sw_components error: "
                    f"unknown PSA SW claim: {claim_id}"
                )
            key["psa_sw_claim"] = psa_sw_claim
        component_num += 1
    return software_components


def make_json_serializable(elem):
    if isinstance(elem,bytes):
        return elem.hex()
    elif isinstance(elem,list):
        return [make_json_serializable(sub_elem) for sub_elem in elem]
    elif isinstance(elem,dict):
        new_dict = {}
        for key in elem.keys():
            new_dict[str(key)] = make_json_serializable(elem[key])
        return new_dict
    else:
        return elem

def compact_view(obj):
    if isinstance(obj, dict):
        out = {}

        for key, value in obj.items():
            if key == "raw" and isinstance(value, str):
                out[key] = value[:1024] + "..." if len(value) > 32 else value
            else:
                out[key] = compact_view(value)

        return out

    elif isinstance(obj, list):
        return [compact_view(x) for x in obj]

    elif isinstance(obj, bytes):
        h = obj.hex()
        return h[:32] + "..." if len(h) > 32 else h

    return obj

def signature_extract(obj):
    if isinstance(obj, dict):
        if obj.get("COSE_sign1_field") == "signature":
            signature_hex = obj["value"]
            signature = (signature_hex)

            if len(signature) != 64:
                raise ValueError("ES256 SIGNATURE must contains 64 byte")

            return signature

        for value in obj.values():
            result = signature_extract(value)
            if result is not None:
                return result

    elif isinstance(obj, list):
        for value in obj:
            result = signature_extract(value)
            if result is not None:
                return result

    return None 

def main():
    with open("token.bin", "r") as f:
        data = f.read()
    data = data.replace("0x", "")
    data = bytes.fromhex(data)
    cbor, end = read_element(data, 0)
    
    print("ROOT TYPE:", cbor.get("type"))
    print("ROOT TAG:", cbor.get("tag"))
    print("END:", end)
    print("TOKEN LENGTH:", len(data))

    cbor_cose_ann, payload = annotate_cosesign1(cbor)

    decoded_payload = build_payload(payload)

    payload_ann = annotate_psa(decoded_payload)
    software_components = annotate_software_components(decoded_payload)
    pprint(
    compact_view(cbor),
    width=100,
    sort_dicts=False
    )

    print("SIGNATURE:")
    print(signature_extract(cbor).hex())

if __name__ == "__main__":
    main()
