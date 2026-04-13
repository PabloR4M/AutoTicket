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
        // nota: "efectivo" y "contado" ya NO están aquí — los manejamos en el nivel 3
        // porque en algunos tickets el total aparece pegado al método de pago
        let exclusiones: [String] = [
            "cambio", "tarjeta", "visa", "mastercard", "amex",
            "sub total", "subtotal", "neto",
            "articulos", "artículos", "piezas", "items",
            "propina", "tip", "descuento", "ahorro",
            "iva", "ieps"
        ]
        
        // ── normaliza un string de monto a Double ──
        // entiende formato mexicano (1,234.56), europeo (1.234,56) y simple (59,95 / 59.95)
        func limpiarMonto(_ raw: String) -> Double? {
            let s = raw.replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces)
            var limpio = s
            // europeo: 1.234,56 → quitar puntos de miles, coma → punto decimal
            if s.range(of: "^[0-9]{1,3}(\\.[0-9]{3})*(,[0-9]{2})$", options: .regularExpression) != nil {
                limpio = s.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            // mexicano/usa: 1,234.56 → solo quitar comas de miles
            } else if s.range(of: "^[0-9]{1,3}(,[0-9]{3})*(\\.[0-9]{2})$", options: .regularExpression) != nil {
                limpio = s.replacingOccurrences(of: ",", with: "")
            // simple con separador: 59,95 o 59.95 → la coma/punto es el decimal
            } else if s.range(of: "^[0-9]+[,.][0-9]{2}$", options: .regularExpression) != nil {
                limpio = s.replacingOccurrences(of: ",", with: ".")
            }
            return Double(limpio)
        }
        
        // extrae todos los montos válidos (con decimales) de un string
        // el patrón bi-formato reconoce tanto 1,234.56 como 1.234,56 como 59,95
        func extraerMontos(de seg: String) -> [Double] {
            let patron = "((?:[0-9]{1,3}(?:[.,][0-9]{3})*)[.,][0-9]{2})"
            guard let regex = try? NSRegularExpression(pattern: patron) else { return [] }
            let rango = NSRange(seg.startIndex..., in: seg)
            return regex.matches(in: seg, range: rango).compactMap { match in
                guard let r = Range(match.range(at: 1), in: seg) else { return nil }
                let v = limpiarMonto(String(seg[r]))
                return (v ?? 0) >= 1.0 ? v : nil   // descartamos valores menores a 1 (número de artículos)
            }
        }
        
        func segmentoEsExcluido(_ seg: String) -> Bool {
            return exclusiones.contains { seg.contains($0) }
        }
        
        // un segmento "total X" es válido solo si:
        // 1. el monto está en los primeros 40 chars (no enterrado en descripción de producto)
        // 2. no contiene asteriscos decorativos de pie de ticket ("total **** i.v.a...")
        func segmentoTotalEsValido(_ seg: String) -> Bool {
            guard !seg.contains("***") else { return false }
            let zonaInicial = String(seg.prefix(40))
            return !extraerMontos(de: zonaInicial).isEmpty
        }
        
        // ── re-segmentación por palabras clave ──
        // resuelve el caso en que Vision colapsa todo el ticket en una sola línea
        // el lookahead (?=...) parte sin consumir la palabra, que queda al inicio del segmento
        // orden importante: los compuestos ("total neto") deben ir ANTES que el simple ("total")
        let patronSplit = [
            "(?=\\btotal\\s+(?:neto|general|a\\s+pagar)\\b)",
            "(?=\\bimporte\\s+(?:total|a\\s+pagar)\\b)",
            "(?=\\bsub\\s*total\\b)",
            "(?=\\biva\\b)",
            "(?=\\bieps\\b)",
            "(?=\\bcontado\\b)",
            "(?=\\befectivo\\b)",
            "(?=\\bcambio\\b)",
            "(?=\\btarjeta\\b)",
            "(?=\\btotal(?!\\s+(?:neto|general|a\\s+pagar))\\b)"
        ].joined(separator: "|")
        
        guard let regexSplit = try? NSRegularExpression(pattern: patronSplit) else { return 0.0 }
        
        // aplicamos la re-segmentación sobre cada línea real (si las hay)
        // y también sobre el texto completo por si todo vino en una línea
        var segmentos: [String] = []
        let lineasBase = textoLimpio.components(separatedBy: .newlines)
        for linea in lineasBase {
            let marcado = regexSplit.stringByReplacingMatches(
                in: linea,
                range: NSRange(linea.startIndex..., in: linea),
                withTemplate: "\n$0"
            )
            let sub = marcado.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            segmentos.append(contentsOf: sub)
        }
        
        // ── nivel 1: frases explícitas de alta confianza ──
        // "total a pagar", "total del pedido", "importe total", "total general"
        let patronesAlta = [
            "^total\\s+(?:a\\s+pagar|del\\s+pedido|de\\s+(?:la\\s+)?(?:compra|cuenta|venta))",
            "^(?:importe\\s+(?:total|a\\s+pagar)|total\\s+general)"
        ]
        for seg in segmentos {
            guard !segmentoEsExcluido(seg) else { continue }
            for patron in patronesAlta {
                if seg.range(of: patron, options: .regularExpression) != nil {
                    if let monto = extraerMontos(de: seg).first { return monto }
                }
            }
        }
        
        // ── nivel 2: "total" solo, monto cerca, sin asteriscos decorativos ──
        for seg in segmentos {
            guard !segmentoEsExcluido(seg) else { continue }
            guard seg.hasPrefix("total"), segmentoTotalEsValido(seg) else { continue }
            // miramos solo los primeros 50 chars para no agarrar montos de descripciones lejanas
            let montos = extraerMontos(de: String(seg.prefix(50)))
            // filtramos enteros chicos que sean número de artículos (ej: "total 1")
            let validos = montos.filter { $0 != Double(Int($0)) || $0 >= 10 }
            if let ultimo = validos.last { return ultimo }
        }
        
        // ── nivel 3 (fallback): primer monto del segmento "efectivo" o "contado" ──
        // en tickets como Zara España, Vision pega el total cobrado al método de pago:
        // "efectivo eur 59.95 100,00" → primer monto (59.95) es el total, el segundo el billete
        for seg in segmentos {
            if seg.hasPrefix("efectivo") || seg.hasPrefix("contado") {
                if let primer = extraerMontos(de: seg).first { return primer }
            }
        }
        
        // ── fallback final: segundo monto más alto de todo el ticket ──
        // el más alto suele ser el billete con que pagaron
        var todosLosMontos: [Double] = []
        for seg in segmentos {
            guard !segmentoEsExcluido(seg) else { continue }
            todosLosMontos.append(contentsOf: extraerMontos(de: seg))
        }
        let ordenados = todosLosMontos.sorted(by: >)
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
