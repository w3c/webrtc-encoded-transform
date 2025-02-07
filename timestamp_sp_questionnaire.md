# Security and Privacy questionnaire

### 2.1. What information does this feature expose, and for what purposes?

This feature exposes three timestamps associated to encoded audio and video
frames:
* Receive Timestamp: time when a media frame was received locally.
* Capture Timestamp: time when a media frame was originally captured, set by
the system that captured the frame.
* Capture Timestamp Server Offset: clock offset between the system that captured
the frame and the system that sent the frame to the local system using this

### 2.2. Do features in your specification expose the minimum amount of information necessary to implement the intended functionality?
Yes.

### 2.3. Do the features in your specification expose personal information, personally-identifiable information (PII), or information derived from either?
No.

### 2.4. How do the features in your specification deal with sensitive information?
This feature does not deal with sensitive information.

### 2.5. Does data exposed by your specification carry related but distinct information that may not be obvious to users?
No.

### 2.6. Do the features in your specification introduce state that persists across browsing sessions?
No.

### 2.7. Do the features in your specification expose information about the underlying platform to origins?
No.

### 2.8. Does this specification allow an origin to send data to the underlying platform?
No.

### 2.9. Do features in this specification enable access to device sensors?
No.

### 2.10. Do features in this specification enable new script execution/loading mechanisms?
No.

### 2.11. Do features in this specification allow an origin to access other devices?
No.

### 2.12. Do features in this specification allow an origin some measure of control over a user agent’s native UI?
No.

### 2.13. What temporary identifiers do the features in this specification create or expose to the web?
None. It exposes timestamps but they do not seem very useful as identifiers.

### 2.14. How does this specification distinguish between behavior in first-party and third-party contexts?
No distinction.

### 2.15. How do the features in this specification work in the context of a browser’s Private Browsing or Incognito mode?
No distinction.

### 2.16. Does this specification have both "Security Considerations" and "Privacy Considerations" sections?
This is a minor addition to an existing specification. The existing specification has a "Privacy and security considerations" section.

### 2.17. Do features in your specification enable origins to downgrade default security protections?
Do features in your spec enable an origin to opt-out of security settings in order to accomplish something? If so, in what situations do these features allow such downgrading, and why?
No.

### 2.18. What happens when a document that uses your feature is kept alive in BFCache (instead of getting destroyed) after navigation, and potentially gets reused on future navigations back to the document?
In this case, peer connection are closed, and the feature becomes inaccessible.

### 2.19. What happens when a document that uses your feature gets disconnected?
In this case, peer connection are closed, and the feature becomes inaccessible.


### 2.20. Does your spec define when and how new kinds of errors should be raised?
This feature does not produce new kinds of errors.

### 2.21. Does your feature allow sites to learn about the user’s use of assistive technology?
No.

### 2.22. What should this questionnaire have asked?
The questions seem appropriate.
