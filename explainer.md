# Explainer - WebRTC Insertable Streams

## Problem to be solved

We need an API for processing media that:
* Allows the processing to be specified by the user, not the browser
* Allows the processed data to be handled by the browser as if it came through
  the normal pipeline
* Allows the use of techniques like WASM to achieve effective processing
* Allows the use of techniques like Workers to avoid blocking on the main thread
* Does not negatively impact security or privacy of current communications


## Approach

This document builds on concepts previously proposed by
[WebCodecs](https://github.com/pthatcherg/web-codecs/), and applies them to the existing
RTCPeerConnection API in order to build an API that is:

* Familiar to existing PeerConnection users
* Able to support insertion of user-defined components
* Able to support high performance user-specified transformations
* Able to support user defined component wrapping and replacement

The central idea is to expose components in an RTCPeerConnection as a collection of
streams (as defined by the [WHATWG Streams API] (https://streams.spec.whatwg.org/)),
which can be manipulated to introduce new components, or to wrap or replace existing
components.


## Use cases

The first use case to be supported by the API is the processing of encoded media, with
end-to-end encryption intended as the motivating application. As such, the first version
of the API will focus on this use case. However, the same approach can be used in future
iterations to support additional use cases such as:

* Funny Hats (processing inserted before encoding or after decoding)
* Background removal
* Voice processing
* Dynamic control of codec parameters
* App-defined bandwidth distribution between tracks
* Custom codecs for special purposes (in combination with WebCodecs)

## Code Examples

1. Let an PeerConnection know that it should allow exposing the data flowing through it
as streams.

To ensure backwards compatibility, if the Insertable Streams API is not used, an
RTCPeerConnection should work exactly as it did before the introduction of this API.
Therefore, we explicitly let the RTCPeerConnection know that we want to use insertable
streams. For example:

<pre>
let pc = new RTCPeerConnection({
    forceEncodedVideoInsertableStreams: true,
    forceEncodedAudioInsertableStreams: true
});
</pre>

2. Set up transform streams that perform some processing on data.

The following example negates every bit in the original data payload
of an encoded frame and adds 4 bytes of padding.

<pre>
    let senderTransform = new TransformStream({
      start() {
        // Called on startup.
      },

      async transform(chunk, controller) {
        let view = new DataView(chunk.data);
        // Create a new buffer with 4 additional bytes.
        let newData = new ArrayBuffer(chunk.data.byteLength + 4);
        Let newView = new DataView(newData);

        // Fill the new buffer with a negated version of all
        // the bits in the original frame.
        for (let i = 0; i < chunk.data.byteLength; ++i)
          newView.setInt8(i, ~view.getInt8(i));
        // Set the padding bytes to zero.
        For (let i = 0; i < 4; ++i)
          newView.setInt8(chunk.data.byteLength + i, 0);

        // Replace the frame's data with the new buffer.
        chunk.data = newData;

        // Send it to the output stream.
        controller.enqueue(chunk);
      },

      flush() {
        // Called when the stream is about to be closed.
      }
    });
</pre>

3. Create a MediaStreamTrack, add it to the RTCPeerConnection and connect the
Transform stream to the track's sender.

<pre>
let stream = await navigator.mediaDevices.getUserMedia({video:true});
let [track] = stream.getTracks();
let videoSender = pc.addTrack(track, stream)
let senderStreams = videoSender.getEncodedVideoStreams();

// Do ICE and offer/answer exchange.

senderStreams.readable
  .pipeThrough(senderTransform)
  .pipeTo(senderStreams.writable);
}
</pre>

4. Do the corresponding operations on the receiver side.

<pre>
let pc = new RTCPeerConnection({forceEncodedVideoInsertableStreams: true});
pc.ontrack = e => {
  let receivers = pc.getReceivers();
  let videoReceiver = null;
  for (const r of receivers) {
    if (r.track.kind == 'video')
      videoReceiver = r;
  }
  if (!videoReceiver)
    return;

  let receiverTransform = new TransformStream({
    start() {},
    flush() {},
    async transform(chunk, controller) {
      // Reconstruct the original frame.
      let view = new DataView(chunk.data);

      // Ignore the last 4 bytes
      let newData = new ArrayBuffer(chunk.data.byteLength - 4);
      let newView = new DataView(newData);

      // Negate all bits in the incoming frame, ignoring the
      // last 4 bytes
      for (let i = 0; i < chunk.data.byteLength - 4; ++i)
        newView.setInt8(i, ~view.getInt8(i));

      chunk.data = newData;
      controller.enqueue(chunk);
      },
    });

    let receiver_streams = video_receiver.createEncodedVideoStreams();
    receiver_streams.readable
      .pipeThrough(my_transform)
      .pipeTo(receiver_streams.writable);
  }
}
</pre>

## API

The following are the IDL modifications proposed by this API.
Future iterations will add additional operations following a similar pattern.

<pre>
// New dictionary.
dictionary RTCInsertableStreams {
    ReadableStream readable;
    WritableStream writable;
};

// New enum for video frame types. Will eventually re-use the equivalent defined
// by WebCodecs.
enum RTCEncodedVideoFrameType {
    "empty",
    "key",
    "delta",
};

// New interfaces to define encoded video and audio frames. Will eventually
// re-use or extend the equivalent defined in WebCodecs.
// The additionalData fields contain metadata about the frame and might be
// eventually be exposed differently.
interface RTCEncodedVideoFrame {
    readonly attribute RTCEncodedVideoFrameType type;
    readonly attribute unsigned long long timestamp;
    attribute ArrayBuffer data;
    readonly attribute ArrayBuffer additionalData;
};

interface RTCEncodedAudioFrame {
    readonly attribute unsigned long long timestamp;
    attribute ArrayBuffer data;
    readonly attribute ArrayBuffer additionalData;
};


// New fields in RTCConfiguration
dictionary RTCConfiguration {
    ...
    boolean forceEncodedVideoInsertableStreams = false;
    boolean forceEncodedAudioInsertableStreams = false;
};

// New methods for RTCRtpSender and RTCRtpReceiver
interface RTCRtpSender {
    // ...
    RTCInsertableStreams createEncodedVideoStreams();
    RTCInsertableStreams createEncodedAudioStreams();
};

interface RTCRtpReceiver {
    // ...
    RTCInsertableStreams createEncodedVideoStreams();
    RTCInsertableStreams createEncodedAudioStreams();
};

</pre>
