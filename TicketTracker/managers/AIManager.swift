import Foundation
import CoreML

class AIManager {
    
    // se recibe el texto del ticket y devuelve la categoría
    func clasificarGasto(textoTicket: String) -> String {
        do {
            // inicializa modelo
            let config = MLModelConfiguration()
            let modelo = try modelo2(configuration: config)
            
            // prediccion
            let prediccion = try modelo.prediction(text: textoTicket)
            
            // etiqueta con mas porcentaje
            return prediccion.label
            
        } catch {
            print("Error al usar el modelo de IA: \(error)")
            return "Desconocido"
        }
    }
}
