import Foundation
import Vision
import UIKit

class VisionManager {
    
    // recibe una imagen y devuelve el texto que encontró
    func extraerTexto(de imagen: UIImage, completion: @escaping (String) -> Void) {
        // se convierte formato a CGImage
        guard let cgImage = imagen.cgImage else {
            completion("")
            return
        }
        
        // petición de leer texto
        let request = VNRecognizeTextRequest { (peticion, error) in
            guard let observaciones = peticion.results as? [VNRecognizedTextObservation], error == nil else {
                print("No se encontró texto o hubo un error: \(String(describing: error))")
                completion("")
                return
            }
            
            // juntamos un solo String gigante
            let textoCompleto = observaciones.compactMap { observacion in
                observacion.topCandidates(1).first?.string
            }.joined(separator: " ")
            
            // se regulariza el formato
            completion(textoCompleto.lowercased())
        }
        
        // configuraciones a español y de precicion
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["es-MX", "es-ES", "en-US"]
        
        // se ejecuta peticion
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("Error al ejecutar Vision: \(error)")
            completion("")
        }
    }
}
