# Explainer - Create functions for encoded data

## Problem to be solved

In some use cases, we need to move encoded data beyond the confines of a single PeerConnection.

The use cases include:

* Relaying incoming encoded data to one or more other PeerConnections as outgoing data [use case 3.2.2](https://w3c.github.io/webrtc-nv-use-cases/#auction)
* Sending data that has already been encoded (by a camera (use case [issue #81](https://github.com/w3c/webrtc-nv-use-cases/issues/81)), from a file (use case [issue #82](https://github.com/w3c/webrtc-nv-use-cases/issues/82)), or other sources)
* Receiving data in encoded form from a non-WebRTC source and processing it using WebRTC (use case [issue #83](https://github.com/w3c/webrtc-nv-use-cases/issues/83))

Addressing these cases in the webrtc-encoded-transform API requires the ability to:

* Create encoded frames
* Clone encoded frames
* Manipulate encoded frame metadata to conform with the requirements of its destination
* Enqueue those frames on a sending or receiving stream that is not the same stream as the frame originated on

These are not the only functions that are needed to handle the use cases, but this explainer
focuses on the frame creation, cloning and manipulation functions.

## Approach

The approach proposed as a minimum viable API consists of 3 functions:

* A constructor that takes encoded data + metadata and creates an encoded frame
* A setter that is able to modify some of the values returned from the existing getMetadata method
* A clone operator that takes an existing encoded frame and creates a new, independent encoded frame

The clone operator may be thought of as a convenient shorthand for the constructor:

```
frame.clone = constructor(frame.getMetadata(), frame.data)

```

## Relevant other needed changes

Creating and inserting frames into or removing frames from an encoded media flow requires the other components handling the media flow to
respond in a reasonable manner.

This may include the need for a number of signals and appropriate treatment thereof:

* If the sink is subject to congestion, the inserting entity must be made aware of the current capacity of the sink
* If the sink can require the transmission of I-frames to resynchronize decoding, those requests must be made available to the inserting entity
* If the source is capable of adapting its transmission rate, the handler taking data from it must be able to make the source aware of its current capacity (which may or may not be the same as the downstream capacity).
* If the source is capable of producing I-frames on demand, the handler taking data from it must be able to make those requests appropriately

It is harmful to the model if there are couplings between the source of encoded data and the sink for encoded data that are not exposed to the handler.
