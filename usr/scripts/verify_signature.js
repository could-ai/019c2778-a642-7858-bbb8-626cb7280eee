const fs = require('fs');
const axios = require('axios');
const path = require('path');

// CONFIGURATION
const DSS_API_URL = 'http://localhost:8080/services/rest/validation/validateSignature';
const PDF_FILE_PATH = process.argv[2]; // Pass file path as argument

if (!PDF_FILE_PATH) {
    console.error('Usage: node verify_signature.js <path-to-signed-pdf>');
    process.exit(1);
}

async function verifySignature() {
    try {
        console.log(`Reading file: ${PDF_FILE_PATH}`);
        const fileBuffer = fs.readFileSync(PDF_FILE_PATH);
        const base64File = fileBuffer.toString('base64');
        const fileName = path.basename(PDF_FILE_PATH);

        // 1. Construct the Payload
        // The DSS API expects a specific JSON structure
        const payload = {
            "signedDocument": {
                "bytes": base64File,
                "digestAlgorithm": null,
                "name": fileName
            },
            "originalDocuments": [], // Required if detached signature, usually empty for PDF
            "policy": null,          // Use default policy
            "signatureId": null,     // Validate all signatures
            "level": null            // Default validation level
        };

        console.log(`Sending request to ${DSS_API_URL}...`);

        // 2. Call the API
        const response = await axios.post(DSS_API_URL, payload, {
            headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
            },
            maxBodyLength: Infinity, // Allow large PDFs
            maxContentLength: Infinity
        });

        // 3. Process the Response
        const report = response.data;
        
        // The 'SimpleReport' is the high-level summary designed for humans/applications
        // It might be nested depending on the DSS version, but usually it's at the root or under 'simpleReport'
        const simpleReport = report.simpleReport || report;

        console.log('\n--- VALIDATION RESULTS ---\n');

        // Check if any signatures exist
        const signatures = simpleReport.signatureOrTimestamp;
        if (!signatures || signatures.length === 0) {
            console.log("❌ No signatures found in the document.");
            return;
        }

        // Handle array or single object
        const sigList = Array.isArray(signatures) ? signatures : [signatures];

        sigList.forEach((sig, index) => {
            console.log(`Signature #${index + 1}:`);
            console.log(`  Signed By: ${sig.signedBy}`);
            console.log(`  Signing Time: ${sig.signingTime}`);
            
            // --- CRITICAL VALIDATION LOGIC ---
            
            // 1. Indication: The global status. 
            // MUST be 'TOTAL_PASSED' for a fully valid signature.
            const indication = sig.indication;
            
            // 2. SubIndication: Gives the reason if not passed.
            const subIndication = sig.subIndication;

            const isValid = (indication === 'TOTAL_PASSED');

            if (isValid) {
                console.log(`  Status: ✅ VALID (TOTAL_PASSED)`);
            } else {
                console.log(`  Status: ❌ INVALID (${indication})`);
                if (subIndication) {
                    console.log(`  Reason: ${subIndication}`);
                }
                
                // Common reasons for failure:
                // - NO_CERTIFICATE_CHAIN_FOUND: The CA is not trusted by the server's keystore.
                // - FORMAT_FAILURE: The signature format is wrong.
                // - EXPIRED: The certificate was expired at signing time.
                // - REVOKED: The certificate has been revoked.
            }
            console.log('-----------------------------------');
        });

    } catch (error) {
        if (error.code === 'ECONNREFUSED') {
            console.error(`\n❌ Connection Refused! \nMake sure the DSS Webapp is running at ${DSS_API_URL}`);
            console.error('See scripts/dss_setup_guide.md for instructions on how to build and run it.');
        } else if (error.response) {
            console.error(`\n❌ API Error: ${error.response.status} ${error.response.statusText}`);
            console.error(JSON.stringify(error.response.data, null, 2));
        } else {
            console.error('\n❌ Error:', error.message);
        }
    }
}

verifySignature();
