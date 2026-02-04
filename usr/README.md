# couldai_user_app

A Flutter application for verifying PDF digital signatures using the EC Europa DSS API.

## Project Structure

- `lib/`: Flutter application code.
- `scripts/`: Node.js utilities and backend setup guides.
  - `verify_signature.js`: A Node.js script to verify signatures via the API.
  - `dss_setup_guide.md`: **READ THIS FIRST** to set up the local DSS backend.

## Getting Started

1. **Setup the Backend**: Follow instructions in `scripts/dss_setup_guide.md` to build and run the DSS Webapp locally.
2. **Run the App**:
   ```bash
   flutter run
   ```
3. **Verify a PDF**: Select a signed PDF in the app. It will communicate with your local DSS instance to verify the signature.

## Resources

- [DSS GitHub Repository](https://github.com/esig/dss)
- [Flutter Documentation](https://docs.flutter.dev/)
