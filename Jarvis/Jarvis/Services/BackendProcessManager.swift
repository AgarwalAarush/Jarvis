import Foundation
import Combine

class BackendProcessManager: ObservableObject {
    @Published var isBackendRunning = false
    @Published var backendStatus = "Stopped"
    
    private var backendProcess: Process?
    private var healthCheckTimer: Timer?
    private let backendPath: String
    private let venvPath: String
    
    init() {
        // Use the embedded backend in Resources
        if let resourcePath = Bundle.main.resourcePath {
            self.backendPath = resourcePath + "/Backend"
        } else {
            // Fallback to development path
            self.backendPath = Bundle.main.bundlePath + "/../../Backend"
        }
        self.venvPath = backendPath + "/venv"
    }
    
    func startBackend() {
        guard !isBackendRunning else { return }
        
        // Check if Python is available
        checkPythonAvailability { [weak self] available in
            if available {
                self?.setupVirtualEnvironment { success in
                    if success {
                        self?.launchBackendProcess()
                    } else {
                        self?.backendStatus = "Failed to setup environment"
                    }
                }
            } else {
                self?.backendStatus = "Python not found. Please install Python 3.x"
            }
        }
    }
    
    func stopBackend() {
        backendProcess?.terminate()
        backendProcess = nil
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
        isBackendRunning = false
        backendStatus = "Stopped"
    }
    
    private func checkPythonAvailability(completion: @escaping (Bool) -> Void) {
        let checkProcess = Process()
        checkProcess.launchPath = "/bin/bash"
        checkProcess.arguments = ["-c", "which python3 || which python"]
        
        let pipe = Pipe()
        checkProcess.standardOutput = pipe
        checkProcess.standardError = pipe
        
        checkProcess.terminationHandler = { process in
            DispatchQueue.main.async {
                completion(process.terminationStatus == 0)
            }
        }
        
        checkProcess.launch()
    }
    
    private func setupVirtualEnvironment(completion: @escaping (Bool) -> Void) {
        backendStatus = "Setting up environment..."
        
        let setupProcess = Process()
        setupProcess.launchPath = "/bin/bash"
        setupProcess.arguments = ["-c", """
            cd "\(backendPath)" && \
            echo "Setting up virtual environment..." && \
            python3 -m venv venv && \
            echo "Activating virtual environment..." && \
            source venv/bin/activate && \
            echo "Installing requirements..." && \
            pip install -r requirements.txt && \
            echo "Setup complete!"
        """]
        
        let pipe = Pipe()
        setupProcess.standardOutput = pipe
        setupProcess.standardError = pipe
        
        setupProcess.terminationHandler = { process in
            DispatchQueue.main.async {
                if process.terminationStatus != 0 {
                    // Read error output for debugging
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? "Unknown error"
                    print("Backend setup failed: \(output)")
                    self.backendStatus = "Setup failed"
                }
                completion(process.terminationStatus == 0)
            }
        }
        
        setupProcess.launch()
    }
    
    private func launchBackendProcess() {
        backendStatus = "Starting backend..."
        
        backendProcess = Process()
        guard let process = backendProcess else { return }
        
        process.launchPath = "/bin/bash"
        process.arguments = ["-c", """
            cd "\(backendPath)" && \
            echo "Activating virtual environment..." && \
            source venv/bin/activate && \
            echo "Starting Jarvis API server..." && \
            python run_api.py
        """]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        process.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                self?.isBackendRunning = false
                self?.backendStatus = process.terminationStatus == 0 ? "Backend stopped" : "Backend crashed"
                self?.healthCheckTimer?.invalidate()
                
                if process.terminationStatus != 0 {
                    // Read error output for debugging
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? "Unknown error"
                    print("Backend process failed: \(output)")
                }
            }
        }
        
        do {
            try process.run()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.startHealthChecks()
            }
        } catch {
            backendStatus = "Failed to start backend: \(error.localizedDescription)"
            print("Failed to launch backend process: \(error)")
        }
    }
    
    private func startHealthChecks() {
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.checkBackendHealth()
        }
    }
    
    private func checkBackendHealth() {
        guard let url = URL(string: "http://localhost:5000/api/v1/health") else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    self?.isBackendRunning = true
                    self?.backendStatus = "Running"
                } else {
                    self?.isBackendRunning = false
                    self?.backendStatus = "Backend not responding"
                }
            }
        }.resume()
    }
    
    func getBackendPath() -> String {
        return backendPath
    }
    
    func isBackendDirectoryValid() -> Bool {
        let fileManager = FileManager.default
        let requirementsPath = backendPath + "/requirements.txt"
        let apiServerPath = backendPath + "/api_server.py"
        
        return fileManager.fileExists(atPath: requirementsPath) && 
               fileManager.fileExists(atPath: apiServerPath)
    }
    
    deinit {
        stopBackend()
    }
}