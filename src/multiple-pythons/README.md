# Multiple Pythons (multiple-pythons)

A feature to install multiple versions of Python via [`asdf`](https://asdf-vm.com).

## Example Usage

```json
"features": {
    "ghcr.io/kennethlove/multiple-pythons:1:": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| versions | A space separated list of Python major versions to install and configure. | string | 3.10 3.11 |
