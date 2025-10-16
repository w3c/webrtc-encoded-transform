# Congestion Control API

This document describes how the congestion control API is expected to work.

The CC API can be applied multiple places in the WebRTC model; the immediate
application is in the Encoded Transform API.


The role of a congestion control API is to inform upstream entities about
reasonable restrictions on how much data they can send downstream. The
expectation from the client should be that as long as they stay within the
indicated restriction, the chance of data loss from buffer overflows should be
reasonably low. The given limits are not a guarantee - either that no packets
will be lost, or that packets will be lost if more than the indicated amount is
sent.

## Representing congestion control status

The following structure represents a congestion control status:
```
interface BandwidthInfo {
    readonly attribute double allocatedBitrate;  // bits per second
    readonly attribute double availableBitrate;
    readonly attribute boolean writable;
    readonly attribute long maxMessageSize; // bytes
};
```
The meaning of the fields is as follows:

* allocatedBitrate: The recommended amount of data for the upstream entity to
  send. By staying below this bitrate, it is likely that packet loss will be
  low, and that the bandwidth is fairly shared with other users.
* availableBitrate: The total available bitrate estimate for the
  downstream link. Exceeding this bitrate will have a high probability of packet
  loss.
* writable: Whether or not a single write of a single message of up to
  maxMessageSize will succeed. If it is false, downstream buffers are known to
  be too full to guarantee success at the time that the information is given.
* maxMessageSize: The size (in bytes) of the largest message that can safely be
  written to the downstream interface.

For the bitrates, an unconstrained status is indicated by a value of positive
infinity.


## Receiving information about downstream congestion control

A downstream interface is expected to expose the following mixin:
```
interface mixin CongestionControlledSink {
  readonly attribute BandwidthInfo bandwidthInfo;
}
```
It is reasonable to read this attribute whenever a send operation has completed,
or just before a send operation is attempted.

If the bandwidthInfo.writable is false, the write operation SHOULD be aborted.

## Sending information upstream about congestion control state
An upstream interface is expected to expose the following mixin:
```
interface mixin CongestionControlledSource {
  undefined sendBandwidthInfo(BandwidthInfo bandwidthInfo);
}
```
This can be called whenever the consumer of the upstream interface deems that
there has been significant change to the congestion control state it wishes the
upstream source to conform to.

Examples of significant changes are:
* The value of "writable" has changed
* The value of "allocatedBitrate" or "availableBitrate" has decreased
* The value of "allocatedBitrate" or "availableBitrate" has increased
  significantly

"Significantly" varies by application.

## Code examples

These examples all assume that RTCRtpScriptTransformer is extended with both
mixins above.

### Transform that doubles message sizes if there's room enough
This might, for example, be a RED type redundancy data appender.

```
function relayBandwidth(transformer) {
  const newBandwidthInfo = transformer.bandwidthInfo;
  newBandwidthInfo.allocatedBitrate =
        newBandwidthInfo.allocatedBitrate / 2;
  transformer.sendBandwidthinfo(newBandwidthInfo);
}

onrtctransform = function(transformerEvent) {
  transformer = transformerEvent.transformer;
  const transform = new TransformStream({
     async transform(encodedFrame, controller) {
        if (encodedFrame.data.byteLength < 
            transformer.bandwidthInfo.maxMessageSize / 2) {
           doDataSizeDoubling(encodedFrame.data);
        }
        if (transformer.bandwidthInfo.writable) {
          controller.enqueue(encodedFrame);
        }
        // Tell upstream about the new half bitrate
        relayBandwidth(transformer);
     }
  });
  relayBandwidth(transformer);
  transformer.sendBandwidthInfo(newbandwidthInfo);
  transformer.readable.pipeThrough(transform)
    .pipeTo(transformer.writable);
}
```

### Transform that allocates half the available bandwith to "important"

```
function relayBandwidth(transformer, important) {
  if (important) {
    const newBandwidthInfo = transformer.bandwidthInfo;
    newBandwidthInfo.allocatedBitrate = newBandwidthInfo.availableBitrate / 2;
    transformer.sendBandwidthinfo(newBandwidthInfo);
  } else {
    // Do a fair division of everyone else's bandwidth
  }
}

function isImportant(transformerEvent) {
  // decide if it's important; if so return true.
  return false;
}

onrtctransform = function(transformerEvent) {
  transformer = transformerEvent.transformer;
  const transform = new TransformStream({
     important: isImportant(transformerEvent),
     async transform(encodedFrame, controller) {
        if (transformer.bandwidthInfo.writable) {
          controller.enqueue(encodedFrame);
        }
        // Tell upstream about the new half bitrate
        relayBandwidth(transformer, important);
     }
  });
  relayBandwidth(transformer, transform.important);
  transformer.sendBandwidthInfo(newbandwidthInfo);
  transformer.readable.pipeThrough(transform)
    .pipeTo(transformer.writable);
}
```


