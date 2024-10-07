## 0.1.2

### waiting external monitor receive parameters ready
```
externalDisplay.connect();
externalDisplay.waitingTransferParameters(
  onReady: () {
    print("Transfer parameters ready, transfer data!");
    externalDisplay.transferParameters(action: "action", value: "data");
  },
  onError: () {
    print("Transfer parameters fail!");
  }
);
```