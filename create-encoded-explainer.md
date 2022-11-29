# Explainer - Create functions for encoded data

## Problem to be solved

In some use cases, we need to move encoded data beyond the confines of a single PeerConnection.

The use cases include:

* Relaying incoming encoded data to one or more other PeerConnections as outgoing data
* Sending data that has already been encoded (by a camera, from a file, or other sources)
* Receiving data in encoded form from a non-WebRTC source and processing it using WebRTC

Addressing these cases in the webrtc-encoded-transform API requires the ability to:

* Create encoded frames
* Clone encoded frames
* Manipulate encoded frame metadata to conform with the requirements of its destination

These are not the only functions that are needed to handle the use cases, but this explainer
focuses on the frame creation, cloning and manipulation functions.

## Approach

The approach proposed as a minimum viable API consists of 3 functions:

* A constructor that takes encoded data + metadata and creates an encoded frame
* A setter that is able to modify some of the values returned from the existing GetMetadata method
* A clone operator that takes an existing encoded frame and creates a new, independent encoded frame

The clone operator may be thought of as a convenient shorthand for the constructor:

```
frame.clone = constructor(frame.getMetadata(), frame.data)

```

