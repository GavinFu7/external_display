## 0.2.1

當 iOS Apps 在 macOS 運行時，External Display 的畫面 會遮蓋 Apps 原本的畫面。所以當檢查到是 macOS 時，停用此套件。

When iOS Apps are running on macOS, the External Display screen will cover the original screen of the Apps. So when macOS is detected, disable this package.

## 0.2.0

外接顯示器支援 FlutterPlugin

External Display support FlutterPlugin

## 0.1.2

新增了 `waitingTransferParametersReady` 功能。
連接外接顯示器後，如果需要立即傳送參數，則需要使用 `waitingTransferParametersReady` 來確保外接顯示器可以接收參數。

Added "waitingTransferParametersReady" function. After connecting an external monitor, if you need to transfer parameters immediately, you need to use "waitingTransferParametersReady" to ensure that the external monitor can receive the parameters.