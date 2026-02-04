# DSS Local Setup Guide for macOS/Linux

This guide explains how to build the Digital Signature Service (DSS) web application locally and expose the REST API required for the Node.js script and Flutter app.

## 1. Prerequisites

- **Java JDK 11 or 17** (DSS v5.10+ requires Java 11+)
- **Maven** (for building the project)
- **Git**

## 2. Clone the Repository

The official repository is hosted by the European Commission's CEF Digital program.

```bash
git clone https://github.com/esig/dss.git
cd dss
```

## 3. Build the Project

**Crucial Step:** You must build the `dss-demo-webapp` module. This is the module that contains the UI *and* the REST API endpoints. If you only build the core libraries, you won't get a running server.

Run this command from the root `dss` folder:

```bash
mvn clean install -DskipTests
```

*Note: This may take a few minutes as it downloads dependencies and builds all modules.*

## 4. Run the Web Application

After the build completes, navigate to the webapp target directory and run the WAR/JAR.

### Option A: Using the Embedded Tomcat (Recommended)
Recent versions of the demo often include an embedded runner or are Spring Boot based.

Look for the executable jar in `dss-demo-webapp/target/`:

```bash
cd dss-demo-webapp/target
java -jar dss-demo-webapp-*.jar
```

### Option B: Deploying WAR to Tomcat
If you generated a `.war` file (e.g., `dss-webapp.war`), download Apache Tomcat 9+, copy the war to `webapps/`, and start Tomcat.

## 5. Verify the API Routes

Once running, the application should be accessible at:
- UI: `http://localhost:8080/` (or `http://localhost:8080/dss-webapp` if on Tomcat)

**The REST API endpoints are located at:**
- Base URL: `http://localhost:8080/services/rest`
- Validation Endpoint: `http://localhost:8080/services/rest/validation/validateSignature`

### Troubleshooting "Missing Routes"
If you get a 404 on the API:
1. **Check the Context Path:** If you deployed to Tomcat as `dss-webapp.war`, your URL is `http://localhost:8080/dss-webapp/services/rest/...`.
2. **Check the Console Logs:** Look for lines starting with `JAX-RS` or `CXF`. They list the registered endpoints on startup.
3. **Wrong Module:** Ensure you are running `dss-demo-webapp`. The `dss-service-rest` module is just a library, not a standalone server.

## 6. Running the Node.js Script

1. Install dependencies:
   ```bash
   cd scripts
   npm install axios
   ```

2. Run the script:
   ```bash
   node verify_signature.js /path/to/your/signed_file.pdf
   ```

## 7. Understanding the Response

To determine if a signature is valid, look at the `SimpleReport` JSON object:

1. **`indication`**: MUST be `TOTAL_PASSED`.
2. **`subIndication`**: If not passed, this explains why (e.g., `NO_CERTIFICATE_CHAIN_FOUND`, `REVOKED`).

If `indication` is `INDETERMINATE`, it usually means the server is missing the Trusted Lists (TL) to verify the certificate chain. You may need to configure the DSS Trusted Lists in the webapp UI or configuration files to trust specific root CAs.
