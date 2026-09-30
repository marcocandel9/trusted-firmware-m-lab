# Set up TF-M attestation experiments

This guide prepares the development environment used to build Trusted Firmware-M (TF-M) 2.3.1 and run its regression tests on the QEMU MPS2-AN521 board. The commands inside the Linux container are the same regardless of the host operating system. The host procedure was tested on macOS Apple Silicon Air M5; Linux and Windows with WSL 2 are possible hosts, but this project's Dockerfile has not been verified on them. For the purpose and results of each experiment, see the [project README](README.md).

## Environment

The tested container uses Ubuntu 24.04, Arm GNU Toolchain 13.3.rel1, CMake, and QEMU. The host needs a Docker-compatible engine that can run Linux containers. Mount the project directory as `/work`.

The project root should contain `Dockerfile`, `SETUP.md`, `trusted-firmware-m/`, `tf-m-tests/`, `experiments/`, and `build/`. Build outputs go in `build/`, outside the two source repositories.

## 1. Prepare the host

Choose a Linux-container runtime for your host:

| Host | Runtime and shell |
| --- | --- |
| macOS | Colima with Docker CLI, or another Docker-compatible Linux-container runtime; run the commands below in a Unix shell. |
| Linux | Docker Engine; run the commands below in a Unix shell. |
| Windows | WSL 2 |


The macOS instructions below document the **tested host setup**. On Linux or Windows, prepare the runtime using its own installation instructions, verify that `docker info` works, then continue at **Build and enter the container**.

### Tested macOS host: Colima

Install Colima , the Docker CLI, and Buildx with brew:

```bash
brew install colima docker docker-buildx

mkdir -p ~/.docker/cli-plugins
ln -sfn "$(brew --prefix)/opt/docker-buildx/bin/docker-buildx" \
  ~/.docker/cli-plugins/docker-buildx

docker buildx version
```

Start the Colima VM with the resources used for this project:

```bash
colima start --cpu 6 --memory 8
colima list
```


## 2. Build and enter the container

In a Unix shell on the host (macOS, Linux, or WSL), go to the project root and run:

```bash
cd /path/to/tfm-dev
docker build -t tfm-dev .
docker run -it --rm -v "$PWD:/work" tfm-dev
```

Replace `/path/to/tfm-dev` with your actual project directory. On the tested Mac, it is `~/Workspaces/tfm-dev`. `docker build` creates the image from the project's `Dockerfile`. In `docker run`, `-it` attaches an interactive terminal, `--rm` automatically removes the container on exit, and `-v "$PWD:/work"` makes the current project directory available at `/work`. Removing the container does not remove files in that mounted directory or the Docker image.

The verified build uses **Arm GNU Toolchain 13.3.rel1**. The Ubuntu 24.04 `gcc-arm-none-eabi` package used during earlier attempts did not satisfy this TF-M toolchain's checks. If the Dockerfile downloads an Arm GNU Toolchain archive for one host CPU architecture, select the matching archive before building on another architecture (for example, `amd64` instead of `arm64`). This Dockerfile has only been tested on the Apple Silicon host described above.

## 3. Obtain matching source checkouts

Inside the container, clone both repositories if they are not already in `/work`:

```bash
cd /work
git clone https://git.trustedfirmware.org/TF-M/trusted-firmware-m.git
git -C /work/trusted-firmware-m checkout TF-Mv2.3.1

git clone -b TF-Mv2.3.1 \
  https://git.trustedfirmware.org/TF-M/tf-m-tests.git
```

Check the revisions before running an experiment:

```bash
git -C /work/trusted-firmware-m describe --tags --always --dirty
git -C /work/tf-m-tests describe --tags --always --dirty
```

The intended release tag for both repositories is `TF-Mv2.3.1`. The experiment build scripts require clean source worktrees so they can apply and remove their patches. Each patch is automatically removed after a succesful or failed experiment build, mantaining a clean worktree.

If Git reports **dubious ownership** for a bind-mounted repository, as frequently happened during the building of the experiments, add that repository as a safe directory *inside the container*:

```bash
git config --global --add safe.directory /work/trusted-firmware-m
git config --global --add safe.directory /work/tf-m-tests
```

If a generated dependency under `/work/build` reports the same error, add the exact path printed by Git. A `--global` setting belongs to the container user's Git configuration; in a container started with `--rm`, it must be recreated on the next run unless the image or a mounted home directory supplies it. The Dockerfile can set the required entries for repeated use, avoiding recurrent dubious ownership error.

## 4. Prepare Python and check the tools

Inside the container:

```bash
cd /work/trusted-firmware-m
python3 -m venv .venv
source .venv/bin/activate
pip install -e .

arm-none-eabi-gcc --version
cmake --version
qemu-system-arm -M help | grep mps2-an521
```

The virtual environment stays under `/work/trusted-firmware-m/.venv`, but activation affects only the current shell. Activate it again after opening a new container or terminal:

```bash
source /work/trusted-firmware-m/.venv/bin/activate
```

Check that the compiler reports Arm GNU Toolchain 13.3.rel1, CMake is at least 3.21, and QEMU lists `mps2-an521`.

## 5. Build and run the baseline

The baseline script first builds the Secure Processing Environment (SPE), including TF-M and the Secure tests. Its `install` target exports `api_ns`. The script then builds the Non-Secure regression tests (NSPE) against that interface. It temporarily enables the token dump in the test source and keeps build results under `/work/build/00_baseline/`.


Inside the container, with the virtual environment active:

```bash
cd /work/experiments/00-baseline
./build.sh
./run_qemu.sh 2>&1 | tee baseline.log
```

QEMU sends the emulated UART output to the terminal. The log should include both Secure and Non-Secure test suites, including their attestation tests and a printed token. To quit QEMU in its `-nographic` terminal, press `Ctrl+A`, then `x`.

For the exact baseline inputs, outputs, and limitations, see [the baseline experiment](experiments/00-baseline/README.md). Other experiment directories have their own `build.sh`, `run_qemu.sh`, patches, and README.

## Returning to the project

Ensure your Docker-compatible runtime is running. On the tested Mac, start Colima with `colima start`; on other hosts, use your chosen runtime. Then, from the project root in a Unix shell:

```bash
cd /path/to/tfm-dev
docker run -it --rm -v "$PWD:/work" tfm-dev
```

Inside the new container:

```bash
source /work/trusted-firmware-m/.venv/bin/activate
cd /work/experiments
```

The project files and build directories are still under `/work`. Rebuilding the image is only needed when the `Dockerfile` or installed tools change. Each experiment's README describes which script to run and what its result establishes.
