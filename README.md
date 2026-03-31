# llama-builder

A llama.cpp builder for amd gfx 1151

## Daily prerelease workflow

The repository includes a GitHub Actions workflow at `.github/workflows/daily-prerelease.yml`.

It is designed for a self-hosted Linux runner with `podman` available, because the build uses the existing container pipeline in this repository and is not expected to succeed on a standard GitHub-hosted runner.

The workflow:

- runs once per day and also supports manual dispatch
- deletes all existing GitHub prereleases before starting a fresh build
- builds and exports binaries with the existing scripts
- packages the `target/` output into a tarball
- publishes a new prerelease with the fixed tag `nightly`

If you want a different upstream ref, edit the workflow default or provide `llama_cpp_ref` when triggering it manually.
