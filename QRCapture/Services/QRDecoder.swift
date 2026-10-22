import CoreGraphics
import Vision

actor QRDecoder {
    func decode(_ image: CGImage) throws -> String? {
        let request = VNDetectBarcodesRequest()
        // Vision scans all supported barcode formats by default, including QR.
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        return request.results?.first?.payloadStringValue
    }
}
