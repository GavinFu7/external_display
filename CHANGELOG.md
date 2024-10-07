## 0.1.3

"waitingTransferParameters" Change To "waitingTransferParametersReady"

External Display support FlutterPlugin

## 0.1.2

### waiting external monitor receive parameters ready
```
externalDisplay.connect();
externalDisplay.waitingTransferParameters(
  onReady: () {
    print("Transfer parameters ready, transfer data!");
    externalDisplay.transferParameters(action: "action", value: "data");
  },
  onError: () { // waiting timeout
    print("Transfer parameters fail!");
  }
);
```