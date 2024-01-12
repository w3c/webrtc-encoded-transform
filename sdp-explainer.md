# SDP negotiation in Encoded Transform

The original definition of encoded transform did not consider negotation; the frames on the "transformed" side went out stamped with the payload type of the frame that came in on the "non-transformed" side (and vice versa for the receiver).

This creates a problem, in that when an encoded transform is applied on the sending side, the bits on the wire may not correspond to what the SDP negotiation has declared that particular type to be used for. When only talking to another instance of the same application, that is not an issue, but it is an issue as soon as we want two different applications to interoperate - for instance when exchanging SFrame encrypted media between two endpoints from different application providers, or when exchanging SFrame encrypted content via an SFU that expects to be able to decode or modify the media.

(The latter is exactly what Sframe is designed to prevent, but it is better for the intermediary to fail clean than to engage in possibly random behavior due to attempting to decode a stream that does not conform to the description it expects.)

This problem is even more acute if an interface resembling RTCRtpScriptTransform is used to add support for codecs not natively supported by the browser; without the ability to influence SDP negotiation, there is no standard way to ensure that a receiver supporting the new codec is able to associate the payload type of incoming packets with the right decoder.

For example, it's been proposed to add [Lyra](https://github.com/google/lyra) to WebRTC using an implementation in WASM; a working example using SDP munging can be found on the
[Meetecho blog](https://www.meetecho.com/blog/playing-with-lyra/).

However, this API proposal does not directly address that use case at the moment.

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
For codec description, we reuse the dictionary RTCRtpCodecCapability, but add a new field describing the
packetization mode to be used.

The requirements on the parameters are:
- either mimetype or fmtp parameters must be different from any existing capability
- the packetization mode must identify a mode known to the UA.

When a codec capability is added, the SDP machinery will negotiate these codecs as normal, and the resulting payload type will be visible in RTCRtp{Sender,Receiver}.getParameters().

## Describing the input and output codecs of transforms

We extend the RTCRTPScriptTransform object's constructor with a fourth argument of type CodecInformation, with the following IDL definition:

```
dictionary CodecInformation {
  sequence<RTCRtpCodecCapabilityWithPacketization> inputCodecs;
  sequence<RTCRtpCodecCapabilityWithPacketization> outputCodecs;
  bool acceptOnlyInputCodecs = false;
}
```
The inputCodecs member describe the media types the transform is prepared to process. Any frame of a format
not listed will be passed to the output of the transform without modification.

The outputCodecs describes the media types the transform may produce.

NOTE: The inputCodecs has two purposes in the "Transform proposal" below - it gives codecs to
negotiate in the SDP, and it serves to filter the frame types that the transform will process.

In order to be able to use the filtering function, the "acceptOnlyInputCodecs" has to be set to true;
if it is false, all frames are delivered to the transform.

The next section has two versions - the Transceiver proposal and the Transform proposal.

## For SDP negotiation - Transceiver proposal
SDP negotiation is inherently an SDP property, and the proper target for that is therefore the RTCRtpTransceiver object.

The transceiver will always be available before an offer or answer is created (either because of AddTrack or AddTransceiver on the sender side,
or in the ontrack event on the side that receives the offer). At that time, the additional codecs to negotiate must be set:

```
transceiver.addCodec(RTCRtpCodecWithPacketization codec, RTCRtpTransceiverDirection direction = "sendrecv")
```
This will add the described codec to the list of codecs to be offered in createOffer/createAnswer. On successful negotiation
of the codec, it will appear in the negotiated codec list returned from setParameters().

Furthermore, the call will instruct the sender to packetize, and the receiver to depacketize, in accordance with the rules for the
codec being given as the packetizationMode argument.

Because it is sometimes inconvenient to intercept every call that creates transceivers, a convenience method is offered on the PC level:

```
pc.addCodecCapability(RTCRtpCodecWithPacketization codec, RTCRtpTransceiverDirection direction = "sendrecv")
```
These calls will act as if the addCodec() call had been invoked on every transceiver created of the associated "kind".

NOTE: The codecs will not show up on the static sender/receiver getCapabilities methods, since these methods can’t distinguish between capabilities used for different PeerConnections or, when using transceiver-level addCodec, for different transceivers. They will show up in the list of codecs in RTCRtp{Sender,Receiver}.getParameters(), so they’re available to the RTCRtpSender for selection or deselection using setCodecPreferences().

When the PeerConnection generates an offer or an answer, the codecs added with addCodec() will be added to the list of codecs generated for that transceiver. If "direction" is sendrecv or recvonly, the selected
payload types will also be added to the list of receive codecs on the m= line; if "direction" is "sendonly", the selected payload types will not be added to the list.

Note: It is the application's job to ensure that the transform and the negotiation agree on which
codecs are being processed.

## For SDP negotiation - Transform proposal

When the PeerConnection generates an offer or an answer:

* If a transform is set on the sender, the process for generating an offer or answer will add the codecs 
  listed in the transform's outputCodecs to the list of codecs available for sending.

* If a transform is set on the receiver, the process for generating an offer or answer will add the codecs 
  listed in the transform's inputCodecs to the list of codecs available for receiving.

When the transform attribute of a sender or receiver is changed, and the relevant codec list changes, the "negotiationneeded" event fires.

## Existing APIs that will be used together with the new APIs
- Basic establishing of EncodedTransform
- getParameters() to get results of codec negotiation
- encoded frame SetMetadata, to set the payload type for processed frames
- setCodecPreferences, to say which codecs (old or new) are preferred for reception

# Example code based on the Transceiver API proposal
```js
customCodec = {
   mimeType: “video/x-encrypted”,
   clockRate: 90000,
   packetizationMode: "video/vp8", 
};

// At sender side
pc.addCodecCapability(customCodec);

// ...after negotiation

const {codecs} = sender.getParameters();

const worker = new Worker(`data:text/javascript,(${work.toString()})()`);
sender.transform = new RTCRtpScriptTransform(worker, {payloadType});

function work() {
  onrtctransform = async ({transformer: {readable, writable, options}}) =>
    await readable.pipeThrough(new TransformStream({transform})).pipeTo(writable);

  function transform(frame, controller) {
    // transform chunk
    let metadata = frame.metadata();
    encryptBody(frame);
    metadata = frame.metadata();
    metadata.mediaType = "video/x-encrypted"
    frame.setMetadata(metadata);
    controller.enqueue(frame);
  }
}

// At receiver side.
const decryptedPT = 208; // Can be negotiated PT or locally-valid
pc.addCodecCapability('video', customCodec);
pc.ontrack = ({receiver}) => {
  const {codecs} = sender.getParameters();
   receiver.addDecodingCodec({mimeType: 'video/vp8', payloadType: decryptedPT});
   const worker = new Worker(`data:text/javascript,(${work.toString()})()`);
   receiver.transform = new RTCRtpScriptTransform(worker, null, null,
                       {inputCodecs: [customCodec], acceptOnlyInputCodecs = True});

  function work() {
    transform = new TransformStream({
      transform: (frame, controller) => {
         // We know that only encrypted-frames will get to this point.
         decryptBody(frame);
         metadata = frame.metadata();
         metadata.mimeType = 'video/vp8';
         frame.setMetadata(metadata);
         controller.enqueue(frame);
       }
     });
     onrtctransform = async({transformer: {readable, writable, options}}) =>
       await readable.pipeThrough(transform).pipeTo(writable);
  }
};
```

# Frequently asked questions

1.  Q: My application wants to send frames with multiple packetizers. How do I accomplish that?

    A: Use multiple payload types. Each will be assigned a payload type. Mark each frame with the payload type they need to be packetized as.

1.  Q: What is the relationship between this proposal and the IETF standard for SFrame?

    A: This proposal is intended to make it possible to implement the IETF standard for SFrame in Javascript, with only the packetizer/depacketizer being updated to support the SFrame packetization rules. It is also intended to make it possible to perform other forms of transform, including the ones that are presently deployed in the field, while marking the SDP with a truthful statement of its content.
