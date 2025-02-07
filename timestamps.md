# Extra Timestamps for encoded RTC media frames

## Authors:

- Guido Urdaneta (Google)

## Participate
- https://github.com/w3c/webrtc-encoded-transform


## Introduction

The [WebRTC Encoded Transform](https://w3c.github.io/webrtc-encoded-transform/)
API allows applications to access encoded media flowing through a WebRTC
[RTCPeerConnection](https://w3c.github.io/webrtc-pc/#dom-rtcpeerconnection). 
Video data is exposed as 
[RTCEncodedVideoFrame](https://w3c.github.io/webrtc-encoded-transform/#rtcencodedvideoframe)s
and audio data is exposed as
[RTCEncodedAudioFrame](https://w3c.github.io/webrtc-encoded-transform/#rtcencodedaudioframe)s.
Both types of frames have a getMetadata() method that returns a number of
metadata fields containing more information about the frames.

This proposal consists in adding a number of additional metadata fields
containing timestamps, in line with recent additions to
[VideoFrameMetadata](https://w3c.github.io/webcodecs/video_frame_metadata_registry.html#videoframemetadata-members)
in [WebCodecs](https://w3c.github.io/webcodecs/) and
[requestVideoFrameCallback](https://wicg.github.io/video-rvfc/#video-frame-callback-metadata-attributes). 

For the purposes of this proposal, we use the following definitions:
* The *capturer system* is a system that originally captures a media frame,
  typically from a local camera, microphone or screen-share session. This frame
  can be relayed through multiple systems before it reaches its final
  destination.
* The *receiver system* is the final destination of the captured frames. It
  receives the data via an [RTCPeerConnection] and it uses the WebRTC Encoded
  Transform API with the changes included in this proposal.
* The *sender system* is the system that communicates directly with the
  *receiver system*. It may be the same as the capturer system, but not
  necessarily. It is the last hop before the captured frames reach the receiver
  system.

The proposed new metadata fields are:
* `receiveTime`: The time when the frame was received from the sender system.
* `captureTime`: The time when the frame was captured by the capturer system.
  This timestamp is set by the capturer system.
* `senderCaptureTimeOffset`: An estimate of the offset between the capturer
  system clock system and the sender system clock. The receiver system can
  compute the clock offset between the receiver system and the sender system
  and these two offset can be used to adjust the `captureTime` to the
  receiver system clock.

`captureTime` and `senderCaptureTimeOffset` are provided in WebRTC by the
[Absolute Capture Time" header extension](https://webrtc.googlesource.com/src/+/refs/heads/main/docs/native-code/rtp-hdrext/abs-capture-time).

Note that the [RTCRtpContributingSource](https://www.w3.org/TR/webrtc/#dom-rtcrtpcontributingsource) 
interface also exposes these timestamps
(see also [extensions[(https://w3c.github.io/webrtc-extensions/#rtcrtpcontributingsource-extensions)]),
but in a way that is not suitable for applications using the WebRTC Encoded
Transform API. The reason is that encoded transforms operate per frame, while
the values in [RTCRtpContributingSource]() are the most recent seen by the UA,
which make it impossible to know if the values provided by
[RTCRtpContributingSource]() actually correspond to the frames being processed
by the application.


## User-Facing Problem

This API supports applications where measuring the delay between the reception
of a media frame and its original capture is useful.

Some examples use cases are:
1. Audio/video synchronization measurements
2. Performance measurements
3. Delay measurements

In all of these cases, the application can log the measurements for offline
analysis or A/B testing, but also adjust application parameters in real time.


### Goals [or Motivating Use Cases, or Scenarios]

- Provide Web applications using WebRTC Encoded Transform access to receive and
  capture timestamps in addition to existing metadata already provided.
- Align encoded frame metadata with [metadata provided for raw frames]().

### Non-goals

- Provide mechanisms to improve WebRTC communication mechanisms based on the
information provided by these new metadata fields.


### Example

This shows an example of an application that:
1. Computes the delay between audio and video
2. Computes the processing and logs and/or updates remote parameters based on the
delay.

```js
// code in a DedicatedWorker
let lastVideoCaptureTime;
let lastAudioCaptureTime;
let lastVideoSenderCaptureTimeOffset;
let lastVideoProcessingTime;
let senderReceiverClockOffset = null;

function updateAVSync() {
  const avSyncDifference = lastVideoCaptureTime - lastAudioCaptureTime;
  doSomethingWithAVSync(avSyncDifference);
}

// Measures delay from original capture until reception by this system.
// Other forms of delay are also possible.
function updateEndToEndVideoDelay() {
  if (senderReceiverClockOffset == null) {
    return;
  }

  const adjustedCaptureTime =
      senderReceiverClockOffset + lastVideoSenderCaptureTimeOffset + lastVideoCaptureTime;
  const endToEndDelay = lastVideoReceiveTime - adjustedCaptureTime;
  doSomethingWithEndToEndDelay(endToEndDelay);
}

function updateVideoProcessingTime() {
  const processingTime = lastVideoProcessingTime - lastVideoReceiveTime;
  doSomethingWithProcessingTime();
}

function createReceiverAudioTransform() {
  return new TransformStream({
    start() {},
    flush() {},
    async transform(encodedFrame, controller) {
      let metadata = encodedFrame.getMetadata();
      lastAudioCaptureTime = metadata.captureTime;
      updateAVSync();
      controller.enqueue(encodedFrame);
    }
  });
}

function createReceiverVideoTransform() {
  return new TransformStream({
    start() {},
    flush() {},
    async transform(encodedFrame, controller) {
      let metadata = encodedFrame.getMetadata();
      lastVideoCaptureTime = metadata.captureTime;
      updateAVSync();
      lastVideoReceiveTime = metadata.receiveTime;
      lastVideoSenderCaptureTimeOffset = metadata.senderCaptureTimeOffset;
      updateEndToEndDelay();
      doSomeEncodedVideoProcessing(encodedFrame.data);
      lastVideoProcessingTime = performance.now();
      updateProcessing();
      controller.enqueue(encodedFrame);
    }
  });
}

// Code to instantiate transforms and attach them to sender/receiver pipelines.
onrtctransform = (event) => {
  let transform;
  if (event.transformer.options.name == "receiverAudioTransform")
    transform = createReceiverAudioTransform();
  else if (event.transformer.options.name == "receiverVideoTransform")
    transform = createReceiverVideoTransform();
  else
    return;
  event.transformer.readable
      .pipeThrough(transform)
      .pipeTo(event.transformer.writable);
};

onmessage = (event) => {
  senderReceiverClockOffset = event.data;
}


// Code running on Window
const worker = new Worker('worker.js');
const pc = new RTCPeerConnection();

// Do ICE and offer/answer exchange. Removed from this example for clarity.

// Configure transforms in the worker
pc.ontrack = e => {
  if (e.track.kind == "video")
    e.receiver.transform = new RTCRtpScriptTransform(worker, { name: "receiverVideoTransform" });
  else  // audio
    e.receiver.transform = new RTCRtpScriptTransform(worker, { name: "receiverAudioTransform" });
}

// Compute the clock offset between the sender and this system.
const stats = pc.getStats();
const remoteOutboundRtpStats = getRequiredStats(stats, "remote-outbound-rtp");
const remoteInboundRtpStats = getRequiredStats(stats, "remote-inbound-rtp")
const senderReceiverTimeOffset = 
    remoteOutboundRtpStats.timestamp - 
        (remoteOutboundRtpStats.remoteTimestamp + 
         remoteInboundRtpStats.roundTripTime / 2);

worker.postMessage(senderReceiverTimeOffset);
```


## Alternatives considered

### [Alternative 1]

Use the values already exposed in `RTCRtpContributingSource`.

`RTCRtpContibutingSource` already exposes the same timestamps as in this proposal.
The problem with using those timestamps is that it is impossible to reliably
associate them to a specific encoded frame exposed by the WebRTC Encoded
Transform API.

This makes any of the computations in this proposal unreliable.

### [Alternative 2]

Expose only `captureTime` and `receiveTime`.

`senderCaptureTimeOffset` is a value that is provided by the 
[Absolute Capture Timestamp]()https://webrtc.googlesource.com/src/+/refs/heads/main/docs/native-code/rtp-hdrext/abs-capture-time#absolute-capture-time
WebRTC header extension, but that extension updates the value only periodically
since there is little value in computing the estimatefor every packet, so it is
strictly speaking not a per-frame value. Arguably, an application could use
the `senderCaptureTimeOffset` already exposed in `RTCRtpContributingSource`.

However, given that this value is coupled with `captureTime` in the header
extension, it looks appropriate and more ergonomic to expose the pair in the
frame as well. While clock offsets do not usually change significantly
in a very short time, there is some extra accuracy in having the estimated
offset between the capturer system and the sender for that particular frame.
This could be more visible, for example, if the set of relays that frames
go through from the capturer system to the sender system changes.

Exposing `senderCaptureTimeOffset` also makes it clearer that the `captureTime`
comes from the original capturer system, so it needs to be adjusted using the
corresponding clock offset.


### [Alternative 3]

Expose a `captureTime` already adjusted to the receiver system's clock.

The problem with this option is that clock offsets are estimates. Using
estimates makes computing A/V Sync more difficult and less accurate.

For example, if the UA uses the a single estimate during the whole session,
the A/V sync computation will be accurate, but the capture times themselves will
be inaccurate as the clock offset estimate is never updated. Any other
computation made with the `captureTime` and other local timestamps will be
inaccurate.

### [Alternative 4]

Expose a `localClockOffset` instead of a `senderClockOffset`.

This would certainly support the use cases presented here, but it would have the
following downsides:
* It would introduce an inconsistency with the values exposed in `RTCRtpContibutingSource`.
  This can lead to confusion, as the `senderClockOffset` is always paired together
  with the `captureTime` in the header extension and developers expect this association.
* Applications can compute their own estimate of the offset between sender
  and receiver using WebRTC Stats and can control how often to update it.
* Some applications might be interested in computing delays using the sender
  as reference.

In short, while this would be useful, the additional value is limited compared
with the clarity, consistency and extra possibilities offered by exposing the
`senderClockOffset`.



## Accessibility, Privacy, and Security Considerations

These timestamps are already available in a form less suitable for applications
using WebRTC Encoded Transform as part of the RTCRtpContributingSource API.

*The `captureTime` field is available via the 
[RTCRtpContributingSource.captureTimestamp](https://w3c.github.io/webrtc-extensions/#dom-rtcrtpcontributingsource-capturetimestamp) field.


*The `senderCaptureTimeOffset` field is available via the
[RTCRtpContributingSource.senderCaptureTimeOffset](https://w3c.github.io/webrtc-extensions/#dom-rtcrtpcontributingsource-sendercapturetimeoffset) field.

*The `receiveTime` field is available via the 
[RTCRtpContributingSource.timestamp](https://w3c.github.io/webrtc-pc/#dom-rtcrtpcontributingsource-timestamp) field.

While these fields are not 100% equivalent to the fields in this proposal,
they have the same privacy characteristics. Therefore, we consider that the
privacy delta of this proposal is zero.

## References & acknowledgements

Many thanks for valuable feedback and advice from:
- Florent Castelli
- Harald Avelstrand
- Henrik Boström
