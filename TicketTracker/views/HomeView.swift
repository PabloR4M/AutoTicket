import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = TicketViewModel()
    
    // Estados para controlar la cámara/galería
    @State private var mostrarSelectorImagen = false
    @State private var imagenSeleccionada: UIImage?
    @State private var tipoDeFuente: UIImagePickerController.SourceType = .photoLibrary
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 25) {
                    
                    // 1. ÁREA DE RESULTADOS (Se muestra solo si ya procesamos un ticket)
                    if let ticket = viewModel.ticketProcesado {
                        VStack(spacing: 15) {
                            Text("Gasto Detectado")
                                .font(.headline)
                                .foregroundColor(.gray)
                            
                            // Total
                            Text(String(format: "$%.2f", ticket.total))
                                .font(.system(size: 50, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Divider()
                            
                            // Categoría y Fecha
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Categoría")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text(ticket.categoria.capitalized)
                                        .font(.title3)
                                        .bold()
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing) {
                                    Text("Fecha")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    if let fecha = ticket.fecha {
                                        Text(fecha, style: .date)
                                            .font(.title3)
                                            .bold()
                                    } else {
                                        Text("No detectada")
                                            .font(.title3)
                                            .bold()
                                    }
                                }
                            }
                        }
                        .padding(25)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                        .padding(.horizontal)
                    } else {
                        // Mensaje inicial
                        VStack {
                            Image(systemName: "doc.viewfinder")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .foregroundColor(.gray.opacity(0.5))
                            Text("Escanea un ticket para comenzar")
                                .foregroundColor(.gray)
                                .padding(.top)
                        }
                        .padding(.top, 50)
                    }
                    
                    // 2. INDICADOR DE CARGA
                    if viewModel.estaProcesando {
                        ProgressView("Leyendo ticket...")
                            .padding()
                    }
                    
                    Spacer(minLength: 40)
                    
                    // 3. BOTONES DE ACCIÓN
                    HStack(spacing: 20) {
                        // Botón Galería (Ideal para el simulador)
                        Button(action: {
                            tipoDeFuente = .photoLibrary
                            mostrarSelectorImagen = true
                        }) {
                            VStack {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.title)
                                Text("Galería")
                                    .font(.caption)
                                    .padding(.top, 2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(15)
                        }
                        
                        // Botón Cámara (Ideal para el iPhone real)
                        Button(action: {
                            tipoDeFuente = .camera
                            mostrarSelectorImagen = true
                        }) {
                            VStack {
                                Image(systemName: "camera")
                                    .font(.title)
                                Text("Cámara")
                                    .font(.caption)
                                    .padding(.top, 2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(15)
                            .shadow(color: Color.blue.opacity(0.3), radius: 5, x: 0, y: 3)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Mis Gastos")
            // 4. AQUÍ ABRIMOS LA CÁMARA O GALERÍA
            .sheet(isPresented: $mostrarSelectorImagen) {
                ImagePicker(imagenSeleccionada: $imagenSeleccionada, sourceType: tipoDeFuente)
            }
            // 5. CUANDO SE SELECCIONA UNA FOTO, LA MANDAMOS A PROCESAR
            .onChange(of: imagenSeleccionada) { nuevaImagen in
                if let imagenParaProcesar = nuevaImagen {
                    viewModel.procesarImagenDeTicket(imagen: imagenParaProcesar)
                }
            }
        }
    }
}

#Preview {
    HomeView()
}
