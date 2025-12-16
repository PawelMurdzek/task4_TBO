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
## trigger przy pushu i pull, więc commituje
## Link z Actions
https://github.com/PawelMurdzek/task4_TBO/actions/runs/20285235767
## Link z wynikami - 155 wykrytych podatności
https://github.com/PawelMurdzek/task4_TBO/security/code-scanning

# Zadanie 4 (obowiązkowe): Uruchomienie aplikacji lokalnie + DAST z wykorzystaniem ZAP

## Komenda
```bash
docker run -d --name myapp-container -p 8080:8080 myapp:latest
docker run --rm -v "${PWD}:/zap/wrk/:rw" -t zaproxy/zap-stable zap-baseline.py -t http://host.docker.internal:8080 -r zap_report.html
```

## Wyniki - 12 wykrytych podatności

### Podsumowanie
| Status | Liczba |
|--------|--------|
| PASS | 55 |
| WARN-NEW | 12 |
| FAIL-NEW | 0 |

### Szczegółowa tabela wyników ZAP

| Alert | Severity | Opis | URL |
|-------|----------|------|-----|
| Missing Anti-clickjacking Header [10020] | Medium | Brak nagłówka `X-Frame-Options` chroniącego przed clickjacking | http://host.docker.internal:8080 |
| X-Content-Type-Options Header Missing [10021] | Low | Brak nagłówka `X-Content-Type-Options: nosniff` | 5 URLi |
| Information Disclosure - Suspicious Comments [10027] | Info | Podejrzane komentarze w kodzie JS (Bootstrap, jQuery) | bootstrap.bundle.min.js, jquery.min.js |
| Content Security Policy (CSP) Header Not Set [10038] | Medium | Brak nagłówka Content Security Policy | 5 URLi |
| Non-Storable Content [10049] | Info | Zawartość nie może być cache'owana | 6 URLi |
| Cookie without SameSite Attribute [10054] | Low | Cookie bez atrybutu `SameSite` | /students/new |
| Permissions Policy Header Not Set [10063] | Low | Brak nagłówka Permissions Policy | 5 URLi |
| Modern Web Application [10109] | Info | Wykryto nowoczesną aplikację webową | /students |
| Session Management Response Identified [10112] | Info | Wykryto zarządzanie sesją | /students/new |
| Absence of Anti-CSRF Tokens [10202] | Medium | Brak tokenów CSRF w formularzach | /students/new, /students/{id} |
| Session ID in URL Rewrite [3] | Medium | JSESSIONID widoczny w URL | /students;jsessionid=... |
| Insufficient Site Isolation Against Spectre [90004] | Low | Brak ochrony przed atakami Spectre | 13 URLi |

## Analiza różnic między DAST a SAST/SCA

### Podatności wykryte TYLKO przez DAST (ZAP), niewykryte przez SAST/SCA

| Podatność | Dlaczego DAST wykrywa | Dlaczego SAST/SCA nie wykrywa |
|-----------|----------------------|------------------------------|
| **Missing Anti-clickjacking Header** | ZAP analizuje rzeczywiste odpowiedzi HTTP serwera i sprawdza obecność nagłówków bezpieczeństwa | SAST analizuje tylko kod źródłowy - konfiguracja nagłówków HTTP często jest w konfiguracji serwera, nie w kodzie |
| **Content Security Policy Not Set** | Wymaga analizy nagłówków HTTP w runtime | CSP jest konfiguracją deploymentu, nie częścią kodu aplikacji |
| **Cookie without SameSite Attribute** | ZAP widzi rzeczywiste cookies ustawiane przez serwer | Atrybuty cookies są często ustawiane przez framework (Spring) na poziomie konfiguracji runtime |
| **Session ID in URL Rewrite** | Wykrywa faktyczne zachowanie sesji w działającej aplikacji | SAST nie widzi jak Tomcat zarządza sesjami w runtime |
| **Absence of Anti-CSRF Tokens** | Analizuje formularze HTML w kontekście całej aplikacji | SAST może nie połączyć szablonów Thymeleaf z logiką backendową |
| **Insufficient Site Isolation (Spectre)** | Sprawdza nagłówki `Cross-Origin-*` w odpowiedziach | To konfiguracja serwera/reverse proxy, nie kod |

### Dlaczego takie różnice występują?

#### 1. **Różny punkt widzenia analizy**
- **SAST (Semgrep)** - analizuje kod źródłowy "od wewnątrz", szuka wzorców niebezpiecznego kodu
- **SCA (Trivy)** - sprawdza znane podatności w zależnościach (CVE)
- **DAST (ZAP)** - testuje działającą aplikację "z zewnątrz", jak prawdziwy atakujący

#### 2. **Konfiguracja vs Kod**
DAST wykrywa problemy wynikające z:
- Konfiguracji serwera aplikacyjnego (Tomcat)
- Ustawień frameworka (Spring Security)
- Konfiguracji HTTP (nagłówki bezpieczeństwa)

Te elementy często **nie są widoczne w kodzie źródłowym** analizowanym przez SAST.

#### 3. **Kontekst runtime**
| Aspekt | SAST | DAST |
|--------|------|------|
| Analiza przepływu danych | Statyczna, teoretyczna | Rzeczywista, w runtime |
| Konfiguracja serwera | Niewidoczna | Pełna widoczność |
| Interakcje między komponentami | Ograniczona | Pełna |
| False positives | Więcej (brak kontekstu) | Mniej (testuje realnie) |

### Wnioski

| Narzędzie | Najlepsze do wykrywania |
|-----------|------------------------|
| **SAST** | Błędy w logice kodu, SQL Injection, XSS w kodzie, hardcoded secrets |
| **SCA** | Znane CVE w bibliotekach, outdated dependencies |
| **DAST** | Błędy konfiguracji, brakujące nagłówki HTTP, problemy z sesją, CSRF |

Wszystkie trzy typy testów są komplementarne i powinny być używane razem w pipeline CI/CD dla pełnego pokrycia bezpieczeństwa.  