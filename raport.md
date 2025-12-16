# Zadanie 1 (opcjonalne): Trivy na lokalnie zbudowanym obrazie Dockera

## Komenda

``` bash
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image myapp:latest
```

## Wynik
```
Report Summary

┌─────────────────────────────┬────────┬─────────────────┬─────────┐
│           Target            │  Type  │ Vulnerabilities │ Secrets │
├─────────────────────────────┼────────┼─────────────────┼─────────┤
│ myapp:latest (ubuntu 24.04) │ ubuntu │       32        │    -    │
├─────────────────────────────┼────────┼─────────────────┼─────────┤
│ app.jar                     │  jar   │       72        │    -    │
└─────────────────────────────┴────────┴─────────────────┴─────────┘
Legend:
- '-': Not scanned
- '0': Clean (no security findings detected)
```
# Zadanie 2 (opcjonalne): SAST z wykorzystaniem Semgrep

## Komenda
```bash
docker run --rm -v "${PWD}:/src" returntocorp/semgrep semgrep scan
```
## Wynik (skrócony)
```
 Dockerfile
   ❯❯❱ dockerfile.security.missing-user-entrypoint.missing-user-entrypoint
          By not specifying a USER, a program in the container may run as 'root'. This is a security hazard.
          If an attacker can control a process running as root, they may have control over the container.
          Ensure that the last USER in a Dockerfile is a USER other than 'root'.
          Details: https://sg.run/k281

           ▶▶┆ Autofix ▶ USER non-root ENTRYPOINT ["java", "-jar", "/app.jar"]
           22┆ ENTRYPOINT ["java", "-jar", "/app.jar"]

    src/main/resources/static/vendors/bootstrap/js/bootstrap.bundle.js
    ❯❱ javascript.lang.security.audit.detect-non-literal-regexp.detect-non-literal-regexp
          RegExp() called with a `configTypes` function argument, this might allow an attacker to cause a
          Regular Expression Denial-of-Service (ReDoS) within your application as RegExP blocks the main
          thread. For this reason, it is recommended to use hardcoded regexes instead. If your regex is run on
          user-controlled input, consider performing input validation or use a regex checking/sanitization
          library such as https://www.npmjs.com/package/recheck to verify that the regex does not appear
          vulnerable to ReDoS.
          Details: https://sg.run/gr65

          213┆ if (!new RegExp(expectedTypes).test(valueType)) {
            ⋮┆----------------------------------------
    ❯❱ javascript.lang.security.audit.detect-non-literal-regexp.detect-non-literal-regexp
          RegExp() called with a `property` function argument, this might allow an attacker to cause a Regular
          Expression Denial-of-Service (ReDoS) within your application as RegExP blocks the main thread. For
          this reason, it is recommended to use hardcoded regexes instead. If your regex is run on user-
          controlled input, consider performing input validation or use a regex checking/sanitization library
          such as https://www.npmjs.com/package/recheck to verify that the regex does not appear vulnerable to
          ReDoS.
          Details: https://sg.run/gr65

          213┆ if (!new RegExp(expectedTypes).test(valueType)) {
```

# Zadanie 3 (obowiązkowe): Przygotowanie procesu CI/CD z wykorzystaniem Trivy i Semgrep

## Plik konfiguracyjny
```yaml
name: Security Scan

on:
  push:
    branches: [ "main" ]
  pull_request:
    branches: [ "main" ]

jobs:
  security-tests:
    runs-on: ubuntu-latest

    steps:
      - name: Check out code
        uses: actions/checkout@v4

      - name: Set up JDK 11
        uses: actions/setup-java@v4
        with:
          java-version: '11'
          distribution: 'temurin'

      - name: Build Docker image
        run: |
          docker build -t myapp:latest .

      - name: Run Trivy vulnerability scan
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'myapp:latest'
          vuln-type: 'os,library'
          format: 'table'
          exit-code: '0'
          severity: 'CRITICAL,HIGH,MEDIUM'

      - name: Run Trivy scan and save results
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'myapp:latest'
          vuln-type: 'os,library'
          format: 'sarif'
          output: 'trivy-results.sarif'

      - name: Upload Trivy scan results to GitHub Security tab
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: 'trivy-results.sarif'

      - name: Install Semgrep
        run: |
          python3 -m pip install semgrep

      - name: Run Semgrep SAST
        run: |
          semgrep scan --config auto --config p/security-audit --sarif --output semgrep-results.sarif .
        continue-on-error: true

      - name: Upload Semgrep results to GitHub Security tab
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: 'semgrep-results.sarif'

      - name: Summary
        run: |
          echo "## Security Scan Complete" >> $GITHUB_STEP_SUMMARY
          echo "Trivy container scan completed" >> $GITHUB_STEP_SUMMARY
          echo "Semgrep SAST scan completed" >> $GITHUB_STEP_SUMMARY
```


# Zadanie 4 (obowiązkowe): Uruchomienie aplikacji lokalnie + DAST z wykorzystaniem ZAP