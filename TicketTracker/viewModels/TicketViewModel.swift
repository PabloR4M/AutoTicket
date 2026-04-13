import Foundation
import SwiftUI
import Combine
import UIKit

class TicketViewModel: ObservableObject {
    
    // pantalla
    @Published var ticketProcesado: Ticket?
    @Published var estaProcesando: Bool = false
    
    // managers/funciones
    private let visionManager = VisionManager()
    private let aiManager = AIManager()
    private let dataExtractor = DataExtractor()
    
    // Funcion Principal
    func procesarImagenDeTicket(imagen: UIImage) {
        self.estaProcesando = true
        
        // manda foto a Vision para sacar el texto
        visionManager.extraerTexto(de: imagen) { textoExtraido in
            
            DispatchQueue.main.async {
                if textoExtraido.isEmpty {
                    print("No se encontró texto")
                    self.estaProcesando = false
                    return
                }
                
                // ↓ PEGA EL DEBUGGER AQUÍ, justo antes de extraerTotal
                print("========= TEXTO CRUDO DE VISION =========")
                let lineasDebug = textoExtraido.lowercased().components(separatedBy: .newlines)
                for (i, linea) in lineasDebug.enumerated() {
                    if linea.contains("total") || linea.contains("contado") ||
                       linea.contains("cambio") || linea.contains("pagar") ||
                       linea.range(of: "[0-9]{3}", options: .regularExpression) != nil {
                        print("[\(String(format: "%02d", i))] |\(linea)|")
                    }
                }
                print("=========================================")
                
                let categoria = self.aiManager.clasificarGasto(textoTicket: textoExtraido)
                let total = self.dataExtractor.extraerTotal(de: textoExtraido)
                let fecha = self.dataExtractor.extraerFecha(de: textoExtraido)
                
                self.ticketProcesado = Ticket(
                    textoExtraido: textoExtraido,
                    categoria: categoria,
                    total: total,
                    fecha: fecha
                )
                
                self.estaProcesando = false
            }
        }
    }
}
