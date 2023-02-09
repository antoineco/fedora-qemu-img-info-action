# Fedora QEMU Image Information Action

A GitHub Action that returns information about a Fedora QEMU disk image from
Fedora's mirrors.

It was originally written as a workflow utility for the [Kernel Devel VM
Action][kdev].

## Usage

### Inputs

- `os` **(required)**: The version code of the Fedora Linux release to fetch
  the QEMU image information for (e.g. "f38").
- `arch`: The machine architecture of the QEMU image in the Linux format (e.g.
  "x86_64"). Defaults to the architecture of the current runner.

### Outputs

- `url`: URL of the Fedora QEMU disk image (e.g.
  "https://<area>mirror.example.com/fedora/linux/releases/37/Cloud/x86_64/images/fedora.qcow2").
- `sha256sum`: SHA256 checksum of the Fedora QEMU disk image.
- `arch`: Machine architecture of the Fedora QEMU disk image.

### Example workflow

```yaml
name: Build Kernel Module

on: push

jobs:
  get-image:
    runs-on: macos-12

    strategy:
      matrix:
        os: [f37, f38, f39]

    steps:
    - name: Get QEMU image info
      id: image
      uses: antoineco/fedora-qemu-img-info-action@v1
      with:
        os: ${{ matrix.os }}

    - name: Cache image
      uses: actions/cache@v3
      with:
        path: ~/images
        key: ${{ github.job }}-${{ runner.os }}-${{ matrix.os }}-${{ steps.image.outputs.sha256sum }}

    - name: Download image
      run: |
        if [[ -e ~/images/fedora.qcow2 ]]; then
          echo '::notice title=Cache hit::The QEMU image is already cached'
          exit 0
        fi
        mkdir -p ~/images
        pushd >/dev/null ~/images
        curl -o fedora.qcow2 ${{ steps.image.outputs.url }}
        echo '${{ steps.image.outputs.sha256sum }}  fedora.qcow2' | sha256sum -c -
        popd >/dev/null
```

For more elaborate usage examples, take a look at the [Kernel Devel VM
Action][kdev-action], or its [CI workflow][kdev-ci].

[kdev]: https://github.com/antoineco/kernel-devel-vm-action
[kdev-action]: https://github.com/antoineco/kernel-devel-vm-action/blob/main/action.yml
[kdev-ci]: https://github.com/antoineco/kernel-devel-vm-action/blob/main/.github/workflows/ci.yaml
[ci]: .github/workflows/ci.yaml
