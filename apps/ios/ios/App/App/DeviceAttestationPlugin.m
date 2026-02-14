#import <Capacitor/Capacitor.h>

CAP_PLUGIN(DeviceAttestationPlugin, "DeviceAttestation",
    CAP_PLUGIN_METHOD(isSupported, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(initialize, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(startSession, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(signCheckpoint, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(signFinal, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(getAttestationEnvelope, CAPPluginReturnPromise);
)
