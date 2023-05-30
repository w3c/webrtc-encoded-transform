# SDP negotiation in Encoded Transform

The original definition of encoded transform did not consider negotation; the frames on the "transformed" side went out stamped with the payload type of the frame that came in on the "non-transformed" side (and vice versa for the receiver).

This creates a problem, in that when an encoded transform is applied on the sending side, the bits on the wire do not correspond to what the SDP negotiation has declared that particular type to be used for. When only talking to another instance of the same application, that is not an issue, but it is an issue as soon as we want two different applications to interoperate - for instance when exchanging Sframe encrypted media between two endpoints from different application providers, or when exchanging Sframe encrypted content via an SFU that expects to be able to decode or modify the media.

(The latter is exactly what Sframe is designed to prevent, but it is better for the intermediary to fail clean than to engage in possibly random behavior due to attempting to decode a stream that does not conform to the description it expects.)

This problem is even more acute when the Encoded Transform is used to add support for payload types not natively supported by the browser; without the ability to influence SDP negotiation, there is no standard way to ensure that a receiver supporting the new codec is able to demultiplex the incoming packets correctly and route them to the right decoder.

# Requirements for an SDP negotiation API
The following things need to be available on such an API:
1. Before SDP negotiation, the application must be able to specify one or more new media types that one wants to negotiate for. As a point of illustration, this document uses the type "video/new-codec".
2. After SDP negotiation, the application must be able to identify if negotiation has succeeded or failed, and what payload type has been assigned for the new media type.
3. Before sending frames, the application must be able to inform the RTP sender of what kind of packetization to use on the outgoing frames.
4. Before receiving frames, the application must be able to inform the RTP receiver of what kind of depacketization to use on the incoming frames.
5. When transforming frames, the sending application must be able to mark the transformed frames with the negotiated payload type before sending.
6. When transforming frames, the receiving application must be able to check that the incoming frame has the negotiated payload type, and (if reenqueueing the frame after transformation) mark the transformed frame with the appropriate payload type for decoding within the RTPReceiver.

# API description

## Codec description
For codec description, we reuse the dictionary RTCRtpCodecCapability, but add a DOMString that identifies the packetization mode.

The requirements on the parameters are:
- either mimetype or fmtp parameters must be different from any existing capability
- if the mimetype is not a known codec, the packetizationMode member MUST be given, and be the mimetype of a known codec.

When a codec capability is added, the SDP machinery will negotiate these codecs as normal, and the resulting payload type will be visible in RTCRtp{Sender,Receiver}.getCapabilities().


## For SDP negotiation
```
PeerConnection.AddSendCodecCapability(DOMString kind, CodecCapability capability)
PeerConnection.AddReceiveCodecCapability(DOMString kind, CodecCapability capability)
```
These calls will add to the lists of codecs being negotiated in SDP, and returned by the calls to GetParameters. (Given the rules for generating SDP, the effect on sendonly/recvonly/sendrecv sections in the SDP will be different. Read those rules with care.)

NOTE: The codecs will not show up on the global GetCapability functions, since these functions can’t distinguish between capabilities used for different PeerConnections. They will show up in the list of codecs in getParameters(), so they’re available for selection or deselection.

## For sending
The RTCRtpSender’s encoder (if present) will be configured to use a specific codec from CodecCapabilities by a new call:
```
RTCRtpSender.SetEncodingCodec(RTCCodecParameters parameters)
```
This sets the MIME type of the codec to encode to, and the payload type that will be put on frames produced by that encoder. This codec must be one supported by the platform (not the “novel” codec), and the PT does not need to be one negotiated in the SDP offer/answer.

When configuring the transform post negotiation, the app MUST retrieve the PTs negotiated for the connection, and identify the PT for the custom codec.

When transforming frames, the transformer configured MUST, in addition to modifying the payload, modify the metadata to have the negotiated PT for the custom codec.

The packetizer will use the rules for the MIME type configured, or the MIME type on the packetizationMode if configured. (This assumes that packetization is independent of FMTP)
## For receiving
The depacketizer will use the rules for the MIME type configured, or the MIME type on the packetizationMode if configured.

The decoder can be configured to accept a given PT as indicating a given codec format by the new API call:
```
AddDecodingCodec(CodecParameters parameters)
```
This does not alter the handling of any otherwise-configured PT, but adds a handler for this specific PT.

On seeing a custom codec in the PT for an incoming frame, if the frame is to be delivered to the corresponding decoder, the encoded frame transform MUST, in addition to transforming the payload, set the PT for the frame to a PT that is understood by the decoder - either by being negotiated or by having been added by AddDecodingCodec.

## Existing APIs that will be used together with the new APIs
- Basic establishing of EncodedTransform
- 

# Example code
(This is incomplete)
```
customCodec = {
   mimeType: “application/x-encrypted”,
   clockRate: 90000,
   fmtp = “encapsulated-codec=vp8”,
   packetizationMode = “video/vp8”,
};

// At sender side
RTCRtpSender.AddCodecCapability(customCodec);
sender = pc.AddTrack(videotrack);
// Negotiate as usual
for (codec in sender.getParameters().codecs) {
   if (codec.mimeType == “application/x-encrypted”) {
      encryptedPT = codec.payloadType;
   }
}
(readable, writable) = sender.getEncodedStreams();

readable.pipeThrough(new TransformStream(
   transform: (frame) => {
       encryptBody(frame);
       metadata = frame.metadata();
       metadata.pt = encryptedPT;
       frame.setMetadata(metadata);
       writable.write(frame);
   }
}).pipeTo(writable);

// At receiver side
RTCRtpReceiver.AddCodecCapability(customCodec);
pc.ontrack = (receiver) => {

   for (codec in receiver.getParameters().codecs) {
      if (codec.mimeType == “application/x-encrypted”) {
         encryptedPT = codec.payloadType;
      }
   }
   receiver.addDecodeCapability({mimeType: video/vp8, payloadType=encryptedPT});
   (readable, writable) = receiver.getEncodedStreams();
   readable.pipeThrough(new TransformStream(
      transform: (frame) => {
         decryptBody(frame);
         metadata = frame.metadata();
         metadata.payloadType = encryptedPT;
         writable.write(frame);
       }
   }).pipeTo(writable);
};
```
