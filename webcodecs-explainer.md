# Interfacing PeerConnection to WebCodecs

This document describes a possible API for integrating PeerConnection to WebCodecs. It builds on previous API suggestions like the SDP control API and the Congestion Control API, and assumes that those are accepted where it makes sense, but defines new functionality that allows for the integration.

Note: This document describes an API for video, but an audio interface should follow exactly the same pattern - it was just a bit tiresome to write “audio and video” everywhere.
## Background: Phases of a PeerConnection
The lifetime of a PeerConnection consists of a number of phases, each characterized by which protocols are actively changing their state in that phase.

1. Configuration stage. This is where Javascript configures the PeerConnection object, before any communication takes place. Example APIs used: setCodecPreferences, addSendCodec
1. SDP Negotiation stage. Here each end learns the capabilities of the other, and configures the PeerConnection appropriately. Example APIs used: createOffer, setLocalDescription, setRemoteDescription and so on.
1. Communication setup. This involves the DTLS handshake and possibly SCTP handshake. This phase establishes the crypto keys for the connection.
1. Media transmission. At this time, RTP and RTCP are the active protocols, and congestion control is the richest source of platform-generated signals.

This proposal aims to leave phases 2-3 untouched, with no new APIs, and add functionality in the configuration stage and media transmission stage as needed.

It assumes that PR 207 (Congestion Control) and PR 186 (SDP manipulation) are both available and implemented.
## Establishing a WebCodec-using sender and/or receiver
When a sender (or receiver, but they’re similar enough that just the sender side is explained in detail here) is first established (through AddTransceiver, through ontrack, or through other means), the sender is in an unconfigured state; it leaves this state either by having its “transform” member set, or by starting to process frames.

There is a set of classes that implement the RTCRtpScriptSink interface (introduced in PR 207). For this version, we assume the same initialization steps as for RTCRtpTransformer.

This mirrors the RTCRtpScriptTransformer interface, but has different semantics:

When applied, the sender will not initialize its encoder component. It will expect all frames to come in via the RTCRtpScriptSink object’s “writable” stream.
When applied, the sender will assume no responsibility for configuring upstream bandwidth or send signals upstream; it will make this information available through the RTCRtpScriptSink object interface only.

A similar process, using the RTCRtpScriptSource interface, applies to the RTPReceiver.

## Getting frames between WebCodecs and RTCPeerConnection
This requires two new sets of constructors:
```
RTCEncodedVideoFrame(EncodedVideoChunk encoded frame,
                     EncodedVideoChunkMetadata,
                     additional metadata as needed)
EncodedVideoChunk(RTCEncodedVideoFrame, additional metadata as needed)
```
and the same thing for audio.

On the raw frame side of WebCodecs, Breakout Box can be used if the application does not create or consume codec video frames directly, but prefers to work with MediaStreamTracks.

## Congestion control and Keyframe control
Congestion control consists of the sender reading the bandwidth attribute of the RTCRtpScriptSink object at each frame event, and configuring the codec’s target bitrate appropriately, by calling the VideoEncoder.configure() method with the appropriate VideoEncoderConfig - the bitrate and framerate are likely controls to be used.

Keyframe requests and other types of feedback from remote sources (such as long term reference frame requests) bubble up through the ScriptSink, and are translated by the controller (JS) into commands to generate keyframes aimed at the encoder, or take appropriate action on other types of feedback.

## Using this interface with other things than WebCodecs
The only part of this interface that depends directly on the WebCodecs specification is the part where one creates an RTCEncodedVideoFrame from an EncodedVideoChunk and vice versa. Any other mechanism that allows creating and consuming an RTCEncodedVideoFrame will be able to use the same API.







