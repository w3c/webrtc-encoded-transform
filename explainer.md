# Explainer - WebRTC Insertable Stream Processing of Media

## Problem to be solved

We need an API for processing media that:
* Allows the processing to be specified by the user, not the browser
* Allows the processed data to be handled by the browser as if it came through
  the normal pipeline
* Allows the use of techniques like WASM to achieve effective processing
* Allows the use of techniques like Workers to avoid blocking on the main thread
* Does not negatively impact security or privacy of current communications

## Approach

This document builds on WebCodecs, and tries to unify the concepts from there with the legacy PeerConnection in order to build an API that is:

* Familiar to existing PeerConnection users
* Able to support user defined component wrapping and replacement
* Able to support high performance user-specified transformations

The central component of the API is the concept (inherited from WebCodecs) of a component’s main role being a TransformStream (part of the WHATWG Streams spec).

A PeerConnection in this model is a bunch of TransformStreams, connected together into a network that provides the functions expected of it. In particular:

* MediaStreamTrack contains a TransformStream (input & output: Media samples)
* RTPSender contains a TransformStream (input: Media samples, output: RTP packets)
* RTPReceiver contains a TransformStream (input: RTP packets, output: Media samples)


RTPSender and RTPReceiver are composable objects - a sender has an encoder and a
RTP packetizer, which pipe into each other; a receiver has an RTP depacketizer
and a decoder.


The encoder is an object that takes a Stream(raw frames) and emits a Stream(encoded frames). It will also have API surface for non-data interfaces like asking the encoder to produce a keyframe, or setting the normal keyframe interval, target bitrate and so on.

## Code examples

In order to insert your own processing in the media pipeline, do the following:

1. Declare a function that does what you want to a single frame.
<pre>
function mungeFunction(frame) { … }
</pre>
2. Set up a transform stream that will apply this function to all frames passed to it.
<pre>
var munger = new TransformStream({transformer: mungeFunction});
</pre>
3. Create a function that will take the original encoder, connect it to the transformStream in an appropriate way, and return an object that can be treated by the rest of the system as if it is an encoder:
<pre>
function installMunger(encoder, context) {
   encoder.readable.pipeTo(munger.writable);
   var wrappedEncoder = { readable: munger.readable,
                          writable: encoder.writable };
   return wrappedEncoder;
}
</pre>
4. Tell the PeerConnection to call this function whenever an encoder is created:
<pre>
pc = new RTCPeerConnection ({
    encoderFactory: installMunger;
});
</pre>

Or do it all using a deeply nested set of parentheses:

<pre>
pc = new RTCPeerConnection( {
    encoderFactory: (encoder) => {
        var munger = new TransformStream({
            transformer: munge
         });
         var wrapped = { readable: munger.readable,
                         writable: encoder.writable };
         encoder.readable.pipeTo(munger.writable);
         return wrappedEncoder;
    }
});
</pre>

The PC will then connect the returned object’s “writable” to the media input, and the returned object’s “readable” to the RTP packetizer’s input.

When the processing is to be done in a worker, we let the factory method pass the pipes to the worker:
<pre>
pc = new RTCPeerConnection({
    encoderFactory: (encoder) => {
       var munger = new TransformStream({ transformer: munge });
       output = encoder.readable.pipeThrough(munger.writable);
       worker.postMessage([‘munge this’, munger], [munger]);
       Return { readable: output, writable: encoder.writable };
    }
 })});      
</pre>
