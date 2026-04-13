import Foundation

class DataExtractor {
    
    // DIAGNÓSTICO TEMPORAL — borrar después
    func debugVision(texto: String) {
        print("========= TEXTO CRUDO DE VISION =========")
        let lineas = texto.lowercased().components(separatedBy: .newlines)
        for (i, linea) in lineas.enumerated() {
            // solo imprimimos líneas que tengan números o palabras clave
            if linea.contains("total") || linea.contains("contado") ||
               linea.contains("cambio") || linea.contains("pagar") ||
               linea.range(of: "[0-9]{3}", options: .regularExpression) != nil {
                print("[\(String(format: "%02d", i))] |\(linea)|")
            }
        }
        print("=========================================")
    }
    
    
    func extraerTotal(de texto: String) -> Double {
        
        let textoLimpio = texto.lowercased()
        
        // palabras que descalifican un segmento completo
        let exclusiones: [String] = [
            "efectivo", "cambio", "tarjeta", "visa", "mastercard", "amex",
            "sub total", "subtotal", "neto",
            "articulos", "artículos", "piezas", "items",
            "propina", "tip", "descuento", "ahorro",
            "iva", "ieps"
        ]
        
        func limpiarMonto(_ raw: String) -> Double? {
            let limpio = raw
                .replacingOccurrences(of: ",", with: "")
                .replacingOccurrences(of: "$", with: "")
                .trimmingCharacters(in: .whitespaces)
            return Double(limpio)
        }
        
        func segmentoEsExcluido(_ seg: String) -> Bool {
            return exclusiones.contains { seg.contains($0) }
        }
        
        // re-segmentamos el texto partiendo en cada palabra clave de ticket
        // esto resuelve el caso en que Vision colapsa todo en una sola línea gigante
        // el lookahead (?=...) parte sin consumir la palabra, que queda al inicio del segmento
        let patronSplit = [
            // primero los compuestos para no partir "total neto" en "total" + "neto"
            "(?=\\btotal\\s+(?:neto|general|a\\s+pagar)\\b)",
            "(?=\\bimporte\\s+(?:total|a\\s+pagar)\\b)",
            "(?=\\bsub\\s*total\\b)",
            "(?=\\biva\\b)",
            "(?=\\bieps\\b)",
            "(?=\\bcontado\\b)",
            "(?=\\befectivo\\b)",
            "(?=\\bcambio\\b)",
            "(?=\\btarjeta\\b)",
            // "total" solo — al final para no interferir con los compuestos de arriba
            "(?=\\btotal(?!\\s+(?:neto|general|a\\s+pagar))\\b)"
        ].joined(separator: "|")
        
        // primero intentamos con saltos de línea reales si los hay
        // si el texto viene todo en una línea, el split por \n da un array de 1 elemento
        // en ambos casos, después re-segmentamos cada trozo por palabras clave
        let lineasBase = textoLimpio.components(separatedBy: .newlines)
        
        var segmentos: [String] = []
        for linea in lineasBase {
            guard let regex = try? NSRegularExpression(pattern: patronSplit) else {
                segmentos.append(linea)
                continue
            }
            // insertamos marcador antes de cada palabra clave y luego partimos por él
            let marcado = regex.stringByReplacingMatches(
                in: linea,
                range: NSRange(linea.startIndex..., in: linea),
                withTemplate: "\n$0"   // $0 preserva la palabra clave al inicio del segmento
            )
            let sub = marcado.components(separatedBy: "\n").map {
                $0.trimmingCharacters(in: .whitespaces)
            }.filter { !$0.isEmpty }
            segmentos.append(contentsOf: sub)
        }
        
        // patrón para extraer cualquier monto con decimales dentro de un segmento
        let patronMonto = "\\$?\\s*((?:[0-9]{1,3}(?:,[0-9]{3})+|[0-9]{1,6})(?:\\.[0-9]{2})?)"
        guard let regexMonto = try? NSRegularExpression(pattern: patronMonto) else { return 0.0 }
        
        func extraerMontos(de seg: String) -> [Double] {
            let rango = NSRange(seg.startIndex..., in: seg)
            return regexMonto.matches(in: seg, range: rango).compactMap { match in
                guard let r = Range(match.range(at: 1), in: seg) else { return nil }
                return limpiarMonto(String(seg[r]))
            }.filter { $0 > 0 }
        }
        
        // orden de búsqueda: del patrón más específico al más genérico
        // para cada tipo buscamos en todos los segmentos antes de bajar al siguiente
        
        // nivel 1 — "total a pagar", "total del pedido": máxima confianza, un solo monto
        for seg in segmentos {
            guard !segmentoEsExcluido(seg) else { continue }
            if seg.range(of: "total\\s+(?:a\\s+pagar|del\\s+pedido|de\\s+(?:la\\s+)?(?:compra|cuenta|venta))",
                         options: .regularExpression) != nil {
                if let monto = extraerMontos(de: seg).first { return monto }
            }
        }
        
        // nivel 2 — "importe total", "total general"
        for seg in segmentos {
            guard !segmentoEsExcluido(seg) else { continue }
            if seg.range(of: "(?:importe\\s+(?:total|a\\s+pagar)|total\\s+general)",
                         options: .regularExpression) != nil {
                if let monto = extraerMontos(de: seg).first { return monto }
            }
        }
        
        // nivel 3 — "total" solo
        // tomamos el ÚLTIMO monto del segmento porque cuando Vision colapsa líneas
        // el orden es siempre: subtotal → iva → TOTAL (el último y más alto)
        for seg in segmentos {
            guard !segmentoEsExcluido(seg) else { continue }
            guard seg.hasPrefix("total") else { continue }
            let montos = extraerMontos(de: seg)
            if let ultimo = montos.last { return ultimo }
        }
        
        // fallback: si la re-segmentación no encontró nada,
        // buscamos el monto más alto en segmentos no excluidos
        // descartando el monto máximo absoluto (que suele ser el billete con que pagaron)
        var todosLosMontos: [Double] = []
        for seg in segmentos {
            guard !segmentoEsExcluido(seg) else { continue }
            todosLosMontos.append(contentsOf: extraerMontos(de: seg))
        }
        
        let ordenados = todosLosMontos.sorted(by: >)
        // el segundo más alto suele ser el total real; el primero suele ser el billete
        return ordenados.dropFirst().first ?? ordenados.first ?? 0.0
    }
    
    
    
    
    // extraer fecha si la tiene forzando el formato de aqui
    func extraerFecha(de texto: String) -> Date? {
        // patron para buscar dia, mes y año separados por guiones, diagonales o espacios
        let patronFecha = "\\b(\\d{2})[/\\-\\s](\\d{2})[/\\-\\s](\\d{2,4})\\b"
        
        do {
            let regex = try NSRegularExpression(pattern: patronFecha)
            
            if let match = regex.firstMatch(in: texto, range: NSRange(texto.startIndex..., in: texto)) {
                let dia = String(texto[Range(match.range(at: 1), in: texto)!])
                let mes = String(texto[Range(match.range(at: 2), in: texto)!])
                var anio = String(texto[Range(match.range(at: 3), in: texto)!])
                
                // si el año viene en dos digitos lo acomoda al formato completo
                if anio.count == 2 {
                    anio = "20" + anio
                }
                
                let fechaString = "\(dia)/\(mes)/\(anio)"
                
                let formatter = DateFormatter()
                formatter.dateFormat = "dd/MM/yyyy"
                
                if let fechaValidada = formatter.date(from: fechaString) {
                    return fechaValidada
                }
            }
        } catch {
            print("error en regex de fecha: \(error)")
        }
        
        // plan b por si viene con texto usando el detector nativo
        do {
            let detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
            let resultados = detector.matches(in: texto, range: NSRange(texto.startIndex..., in: texto))
            
            // devuelve la primera fecha que encuentre
            return resultados.first?.date
        } catch {
            print("error al detectar fecha: \(error)")
            return nil
        }
    }
}
