# TAG Review: Security and Privacy questionnaire

### 2.1. What information might this feature expose to Web sites or other parties, and for what purposes is that exposure necessary?
This API exposes encoded audio and video frames from peer connections and metadata associated with them.
The API also exposes a way to write arbitrary audio and video frame data (not metadata) to the WebRTC network packetizer in RTCRtpSenders, and to decoders in RTCRtpReceivers. The API does not allow the ability to create frames. The only frames that can be written are previously received frames, and only the media payload can be modified.
This exposure is required to allow processing of encoded audio and video data, which is the main use case this API intends to support. For example, an application may append additional metadata to a frame, may encrypt it, or may leave it unmodified and just use the metadata to provide diagnostics.
Note that media data is already exposed to the web in less ergonomic ways. For example, encoded audio and video data from a peer connection can be exposed via MediaRecorder. Decoded versions of the same data can be exposed via media elements. Some of the metadata is also already exposed.

### 2.2. Is this specification exposing the minimum amount of information necessary to power the feature?
Yes. The need to expose the audio/video encoded payloads is obvious based on the intended use case (encoded media processing).
With regards to the exposed metadata, it can be said that many specific use cases need access to metadata in order to function properly. For example, some applications may append extra data to the payload that can be used by the remote end together with the exposed metadata to to validate payloads.

### 2.3. How does this specification deal with personal information or personally-identifiable information or information derived thereof?
No extra personal information or personally-identifiable information is exposed by this API.

### 2.4. How does this specification deal with sensitive information?
No extra sensitive information is exposed by this API.

### 2.5. Does this specification introduce new state for an origin that persists across browsing sessions?
No.

### 2.6. What information from the underlying platform, e.g. configuration data, is exposed by this specification to an origin?
None.

### 2.7. Does this specification allow an origin access to sensors on a user’s device
No.

### 2.8. What data does this specification expose to an origin? Please also document what data is identical to data exposed by other features, in the same or different contexts.
As mentioned above, this API exposes encoded media data in a manner that makes it easy to do encoded media processing. It also exposes metadata associated with each frame.
Media data and some of the metadata exposed by this API is already exposed by other APIs such as MediaRecorder, getStats() and media elements. T
Streams that are tainted with another origin cannot be accessed with this API, as that would break the isolation rule.

### 2.9. Does this specification enable new script execution/loading mechanisms?
No

### 2.10. Does this specification allow an origin to access other devices?
No.

### 2.11. Does this specification allow an origin some measure of control over a user agent’s native UI?
No.

### 2.12. What temporary identifiers might this specification create or expose to the web?
It exposes WebRTC synchronization sources and contributing sources (already exposed through other APIs).

### 2.13. How does this specification distinguish between behavior in first-party and third-party contexts?
Streams that are tainted with another origin cannot be accessed with this API, as that would break the isolation rule.

### 2.14. How does this specification work in the context of a user agent’s Private Browsing or "incognito" mode?
No difference.

### 2.15. Does this specification have a "Security Considerations" and "Privacy Considerations" section?
Yes.

### 2.16. Does this specification allow downgrading default security characteristics?
No.

### 2.17. What should this questionnaire have asked?
The questions seem adequate.

