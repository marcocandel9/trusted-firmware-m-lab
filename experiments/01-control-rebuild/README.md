# 01-control-rebuild

This experiment rebuilds the baseline using the same source code and patches, but at a different time and in a different output directory. The attestation tokens show different hashes in the software components claim for both the Secure (SPE) and Non-Secure (NSPE) images.

This control was added after [01-measured-boot](../01-measured-boot/README.md). In that experiment, a Non-Secure source string was changed to see whether the measured hash changed. The control rebuild shows why a direct comparison with the baseline token cannot, by itself, establish that the source edit caused the hash difference.

## Differences in the Secure image

The generated header records the build time. To compare the two headers:

```bash
grep -RInF --include=tfm_version.h 'BUILD_TIMESTAMP' \
  /work/build/00_baseline/build_spe \
  /work/build/01_control_rebuild/build_spe
```

Output:

```text
/work/build/00_baseline/build_spe/build-spe/generated/secure_fw/spm/include/tfm_version.h:26:#define BUILD_TIMESTAMP "Mon 21 Sep 2026 13:42:13"
/work/build/01_control_rebuild/build_spe/build-spe/generated/secure_fw/spm/include/tfm_version.h:26:#define BUILD_TIMESTAMP "Mon 21 Sep 2026 17:21:24"
```

The two timestamp strings are also present in the corresponding Secure binaries:

```bash
arm-none-eabi-strings /work/build/00_baseline/build_spe/bin/tfm_s.bin |
  grep -F 'Mon 21 Sep 2026 13:42:13'

arm-none-eabi-strings /work/build/01_control_rebuild/build_spe/bin/tfm_s.bin |
  grep -F 'Mon 21 Sep 2026 17:21:24'
```

Output, respectively (the `[1;34m` prefix shown by the terminal is part of a color escape sequence):

```text
[1;34mMon 21 Sep 2026 13:42:13 UTC
[1;34mMon 21 Sep 2026 17:21:24 UTC
```

A byte comparison identifies five differences:

```bash
cmp -lb \
  /work/build/00_baseline/build_spe/bin/tfm_s.bin \
  /work/build/01_control_rebuild/build_spe/bin/tfm_s.bin
```

```text
242132  63 3     67 7
242134  64 4     62 2
242135  62 2     61 1
242137  61 1     62 2
242138  63 3     64 4
```

These are exactly the five changed timestamp digits: `13:42:13` versus `17:21:24`. For these two Secure binaries, the recorded timestamp explains the byte differences observed by `cmp`. The Secure binary is therefore different even though the source code and patches are the same.

## Differences in the Non-Secure image

The Non-Secure binaries also differ. To inspect their byte differences:

```bash
cmp -lb \
  /work/build/00_baseline/build_test/bin/tfm_ns.bin \
  /work/build/01_control_rebuild/build_test/bin/tfm_ns.bin
```

Excerpt of the output:

```text
   553 360 M-p  370 M-x
   589 360 M-p  370 M-x
 77921 260 M-0  270 M-8
 78101 260 M-0  270 M-8
 78109 240 M-   250 M-(
 78185 254 M-,  264 M-4
 83925  44 $     54 ,
115042  60 0     61 1
115044 142 b    143 c
115045 141 a    157 o
115046 163 s    156 n
115047 145 e    164 t
115048 154 l    162 r
115049 151 i    157 o
115050 156 n    154 l
115051 145 e    137 _
115052  57 /    162 r
115053 142 b    145 e
115054 165 u    142 b
115055 151 i    165 u
115056 154 l    151 i
115057 144 d    154 l
115058 137 _    144 d
115059 163 s     57 /
115060 160 p    142 b
115061 145 e    165 u
115062  57 /    151 i
115063 141 a    154 l
115064 160 p    144 d
115065 151 i    137 _
115066 137 _    163 s
115067 156 n    160 p
115068 163 s    145 e
115070 160 p    141 a
115071 154 l    160 p
115072 141 a    151 i
115073 164 t    137 _
115074 146 f    156 n
115075 157 o    163 s
115076 162 r     57 /
115077 155 m    160 p
115078  57 /    154 l
115079 145 e    141 a
115080 170 x    164 t
115081 164 t    146 f
115082  57 /    157 o
115083 143 c    162 r
115084 157 o    155 m
115085 155 m     57 /
115086 155 m    145 e
115087 157 o    170 x
115088 156 n    164 t
115090 165 u    143 c
115091 141 a    157 o
115092 162 r    155 m
115093 164 t    155 m
115094 137 _    157 o
115095 163 s    156 n
115096 164 t     57 /
115097 144 d    165 u
115098 157 o    141 a
115099 165 u    162 r
115101  56 .    137 _
115102 143 c    163 s
115103   0 ^@   164 t
115104   0 ^@   144 d
115105 163 s    157 o
115106 164 t    165 u
115107 144 d    164 t
115108 151 i     56 .
115109 157 o    143 c
115110 137 _      0 ^@
115111 151 i      0 ^@
115112 156 n      0 ^@
115113 151 i    163 s
115115   0 ^@   144 d
115116   0 ^@   151 i
115117   4 ^D   157 o
115118   2 ^B   137 _
115119   2 ^B   151 i
115120   2 ^B   156 n
115121 105 E    151 i
115122  65 5    164 t
115123  21 ^Q     0 ^@
115125 155 m      4 ^D
...
```

The path of each build is embedded in its Non-Secure binary. `strings -t d` prints the starting offset of each string in decimal:

```bash
arm-none-eabi-strings -t d \
  /work/build/00_baseline/build_test/bin/tfm_ns.bin |
  grep -F '/work/build/' | head -n 10

arm-none-eabi-strings -t d \
  /work/build/01_control_rebuild/build_test/bin/tfm_ns.bin |
  grep -F '/work/build/' | head -n 10
```

The relevant output is:

```text
115028 /work/build/00_baseline/build_spe/api_ns/platform/ext/common/uart_stdout.c
115028 /work/build/01_control_rebuild/build_spe/api_ns/platform/ext/common/uart_stdout.c
```

Both paths start at offset `115028`. Their first 13 characters, `/work/build/0`, are identical. The next character is `0` in the baseline and `1` in the control rebuild.

Here the commands use different counting conventions: the offset printed by `strings -t d` starts at **zero**, while the first column of `cmp -lb` starts at **one**. Thus the first different path byte appears at `115028 + 13 + 1 = 115042` in `cmp`:

```text
115042  60 0     61 1
```

The following output shows more differences in and around these paths. Since the directory names have different lengths, differences at later positions cannot all be interpreted by aligning the two `cmp` columns character by character.

There are also **seven differences before this path begins** (positions 553 through 83925 in the excerpt). Their cause has not been established here. The embedded paths explain some differences, but the full Non-Secure binary difference cannot be attributed solely to them.

## Conclusion

The same source code and patches, built at different times and in different output directories, produced different Secure and Non-Secure binaries and different software-component hashes in the observed tokens. In the Secure image, the five observed byte differences match the timestamp digits. In the Non-Secure image, the build paths account for some differences, while the earlier bytes remain unexplained.

This control limits what can be concluded from [01-measured-boot](../01-measured-boot/README.md): the `[E1]` string is present in that experiment's Non-Secure binary, but comparing its token with a separately built baseline token does not isolate the patch as the cause of the hash difference.
