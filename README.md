# secsi

A simple script to get dependabot alerts either all repositories in an GitHub organisation or for a GitHub teams repositories in the organisation.

## Prerequisites

- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
- [gh-cli](https://github.com/cli/cli?tab=readme-ov-file#installation)
- [jq](https://jqlang.github.io/jq/download/)

## Usage

1. Clone repository

   ```sh
   git clone https://github.com/psilore/secsi.git
   ```

2. Navigate to directory

   ```sh
   cd secsi
   ```

### Get dependabot alerts in an GitHub organisation

```sh
bash secsi.sh -o [OWNER]
```

### Get dependabot alerts for a GitHub teams repositories within an organisation

```sh
bash secsi.sh -o [OWNER] -t [TEAM_SLUG]
```
