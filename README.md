# deploy

Compose stacks, the installer, and the upgrade and migration notes. A Helm chart later.

This repository holds no product code. What it holds is the shape an operator copies:
the deployment profiles, the settings applied to every container, what has to be open
between components and what must not be, and what a migration asks of a running
installation.

| Directory | What it installs |
| --- | --- |
| [single-host/](single-host/) | The whole installation on one Linux host, from one Compose file: [Profile A](https://agentiik.github.io/docs/#profile-a-a-single-host). Its README is the guide, from an empty host to a first workflow run. |
| [runner/](runner/) | A runner on a Linux machine of its own, from one Compose file, joining any installation it reaches. |

The other deployment profiles are specified at <https://agentiik.github.io/docs#deployment>, and the roadmap says which release brings each.

## Licence

Apache-2.0, see [LICENSE](LICENSE). Configuration people copy into their own
infrastructure should not carry an obligation with it. [LICENSING.md](https://github.com/agentiik/.github/blob/main/LICENSING.md)
has the reasoning.

## Contributing

[CONTRIBUTING.md](https://github.com/agentiik/.github/blob/main/CONTRIBUTING.md), under the Developer Certificate of Origin 1.1.
