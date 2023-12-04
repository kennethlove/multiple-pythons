# Multiple Pythons (multiple-pythons)

A feature to install multiple versions of Python via [`asdf`](https://asdf-vm.com).

## Example Usage

```json
"features": {
    "ghcr.io/kennethlove/multiple-pythons:1:": {}
}
```

or

```json
"features": {
    "ghcr.io/kennethlove/multiple-pythons:1:": {
        "versions": "3.10 3.11 3.12"
    }
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| versions | A space separated list of Python major versions to install and configure. | string | 3.10 3.11 |

## Notes

- This feature will install `asdf` as the devcontainer `remoteUser`. It will also
configure profiles and autocompletions for each of the following shells:
  - bash
  - zsh
  - fish
- The latest Python version provided in the `versions` list will be set as the
global version in `asdf` by default. The user can change this afterwards.

# Credits

This feature is heavily borrowed from ["Hypermodern Python"](https://github.com/natescherer/devcontainers-custom-features).
