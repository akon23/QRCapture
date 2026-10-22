import CoreGraphics
import Vision

actor QRDecoder {
    func decode(_ image: CGImage) throws -> String? {
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        return request.results?.first?.payloadStringValue
    }
}
