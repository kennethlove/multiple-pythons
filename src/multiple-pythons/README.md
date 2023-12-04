
# Multiple Pythons (multiple-pythons)

A feature to install multiple Python versions via asdf.

## Example Usage

```json
"features": {
    "ghcr.io/kennethlove/multiple-pythons/multiple-pythons:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| versions | A space separated list of Python major versions to install and configure. | string | 3.10 3.11 |

# Notes

- This feature will install `asdf` as the devcontainer `remoteUser`. It will also
configure profiles and autocompletions for each of the following shells:
  - bash
  - zsh
  - fish
- The latest Python version provided in the `versions` list will be set as the
global version in `asdf` by default. The user can change this afterwards.

# Credits

This feature is heavily borrowed from ["Hypermodern Python"](https://github.com/natescherer/devcontainers-custom-features).


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/kennethlove/multiple-pythons/blob/main/src/multiple-pythons/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
