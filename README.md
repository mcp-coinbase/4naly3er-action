# 4naly3er Action [DRAFT]

This action allows you to run the [Slither static
analyzer](https://github.com/crytic/slither) against your project, from within a
GitHub Actions workflow.

To learn more about [Slither](https://github.com/crytic/slither) itself, visit
its [GitHub repository](https://github.com/crytic/slither) and [wiki
pages](https://github.com/crytic/slither/wiki).

- [How to use](#how-to-use)
- [Github Code Scanning integration](#github-code-scanning-integration)
- [Examples](#examples)

## How to use


### Options

| Key              | Description
|------------------|------------
| `ignore-compile` | If set to true, the Slither action will not attempt to compile the project. False 


### Advanced compilation

If the project requires advanced compilation settings or steps, set
`ignore-compile` to true and follow the compilation steps before running
Slither. You can find an example workflow that uses this option in the
[examples](#examples) section.

### Action fail behavior

The Slither action supports a `fail-on` option, based on the `--fail-*` flags
added in Slither 0.8.4. To maintain the current action behavior, this option
defaults to `all`. The following table summarizes the action behavior across
different Slither versions. You may adjust this option as needed for your
workflows. If you are setting these options on your config file, set `fail-on:
config` to prevent the action from overriding your settings.

| `fail-on`          | Slither <= 0.8.3          | Slither > 0.8.3
|--------------------|---------------------------|----------------
| `all` / `pedantic` | Fail on any finding       | Fail on any finding

† Note that if you use `fail-on: none` with Slither 0.8.3 or earlier, certain
functionality may not work as expected. In particular, Slither will not produce
a SARIF file in this case. If you require `fail-on: none` behavior with the
SARIF integration, consider adding [`continue-on-error:
true`](https://docs.github.com/es/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idstepscontinue-on-error)
instead to the action step.

### Using a different Slither version

If the latest Slithe

## Github Code Scanning integration

The action supports the Github Code Scanning integration, which will push
Slither's alerts to the Security tab of the Github project (see [About code
scanning](https://docs.github.com/en/code-security/code-scanning/automatically-scanning-your-code-for-vulnerabilities-and-errors/about-code-scanning)).
This integration eases the triaging of findings and improves the continuous
integration.

### Code Scanning preview

#### Findings Summary
<img src="summary.png" alt="Summary" width="500"/>

#### Findings Details
<img src="details.png" alt="Summary" width="500"/>

### How to use

To enable the integration
