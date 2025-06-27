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
        
        // Log path information for debugging
        print("BackendProcessManager initialized:")
        print("  Backend path: \(backendPath)")
        print("  Virtual env path: \(venvPath)")
        print("  Resource path: \(Bundle.main.resourcePath ?? "nil")")
        print("  Bundle path: \(Bundle.main.bundlePath)")
        print("  Backend directory exists: \(FileManager.default.fileExists(atPath: backendPath))")
        print("  Backend directory is valid: \(isBackendDirectoryValid())")
    }
    
    func startBackend() {
        guard !isBackendRunning else { 
            print("Backend is already running")
            return 
        }
        
        print("Starting backend process...")
        
        // First validate backend directory structure
        guard isBackendDirectoryValid() else {
            backendStatus = "Backend files not found in app bundle"
            print("Backend validation failed - required files missing:")
            let requirementsPath = backendPath + "/requirements.txt"
            let apiServerPath = backendPath + "/run_api.py"
            print("  requirements.txt exists: \(FileManager.default.fileExists(atPath: requirementsPath))")
            print("  run_api.py exists: \(FileManager.default.fileExists(atPath: apiServerPath))")
            return
        }
        
        // Check if Python is available
        checkPythonAvailability { [weak self] available in
            if available {
                print("Python is available, setting up virtual environment...")
                self?.setupVirtualEnvironment { success in
                    if success {
                        print("Virtual environment setup successful, launching backend...")
                        self?.launchBackendProcess()
                    } else {
                        print("Virtual environment setup failed")
                        self?.backendStatus = "Failed to setup environment"
                    }
                }
            } else {
                print("Python not found on system")
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
        print("Setting up virtual environment at: \(venvPath)")
        
        // Check if virtual environment already exists
        if FileManager.default.fileExists(atPath: venvPath + "/bin/activate") {
            print("Virtual environment already exists, skipping creation")
            completion(true)
            return
        }
        
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
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? "Unknown error"
                
                if process.terminationStatus != 0 {
                    print("Backend setup failed with status \(process.terminationStatus):")
                    print(output)
                    self.backendStatus = "Setup failed: \(output.prefix(100))"
                } else {
                    print("Backend setup completed successfully")
                    print("Setup output: \(output)")
                }
                completion(process.terminationStatus == 0)
            }
        }
        
        do {
            try setupProcess.run()
        } catch {
            print("Failed to launch setup process: \(error)")
            DispatchQueue.main.async {
                self.backendStatus = "Failed to launch setup: \(error.localizedDescription)"
                completion(false)
            }
        }
    }
    
    private func launchBackendProcess() {
        backendStatus = "Starting backend..."
        print("Launching backend process...")
        
        backendProcess = Process()
        guard let process = backendProcess else { 
            print("Failed to create backend process")
            return 
        }
        
        // Determine which Python script to run
        let runApiPath = backendPath + "/run_api.py"
        let apiServerPath = backendPath + "/api_server.py"
        let scriptToRun = FileManager.default.fileExists(atPath: runApiPath) ? "run_api.py" : "api_server.py"
        
        print("Using Python script: \(scriptToRun)")
        
        process.launchPath = "/bin/bash"
        process.arguments = ["-c", """
            cd "\(backendPath)" && \
            echo "Activating virtual environment..." && \
            source venv/bin/activate && \
            echo "Current directory: $(pwd)" && \
            echo "Python version: $(python --version)" && \
            echo "Starting Jarvis API server with \(scriptToRun)..." && \
            python \(scriptToRun)
        """]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        process.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                self?.isBackendRunning = false
                self?.backendStatus = process.terminationStatus == 0 ? "Backend stopped" : "Backend crashed"
                self?.healthCheckTimer?.invalidate()
                
                // Always read output for debugging
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? "Unknown error"
                
                if process.terminationStatus != 0 {
                    print("Backend process failed with status \(process.terminationStatus):")
                    print(output)
                } else {
                    print("Backend process ended normally:")
                    print(output)
                }
            }
        }
        
        do {
            try process.run()
            print("Backend process started successfully")
            
            // Give backend time to start before health checks
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                print("Starting health checks...")
                self.startHealthChecks()
            }
        } catch {
            let errorMsg = "Failed to start backend: \(error.localizedDescription)"
            backendStatus = errorMsg
            print(errorMsg)
        }
    }
    
    private func startHealthChecks() {
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.checkBackendHealth()
        }
    }
    
    private func checkBackendHealth() {
        // Try port 5001 first (since 5000 is often used by AirPlay), then 5000
        let ports = [5001, 5000]
        
        for port in ports {
            guard let url = URL(string: "http://localhost:\(port)/api/v1/health") else { 
                continue
            }
            
            checkHealthAtURL(url, port: port)
            break // Only check the first available port
        }
    }
    
    private func checkHealthAtURL(_ url: URL, port: Int) {
        print("Health check: trying \(url)")
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Health check failed on port \(port): \(error.localizedDescription)")
                    
                    // If this was port 5001 and it failed, try 5000
                    if port == 5001 {
                        self?.tryHealthCheckOnPort(5000)
                    } else {
                        self?.isBackendRunning = false
                        self?.backendStatus = "Backend not responding: \(error.localizedDescription)"
                    }
                } else if let httpResponse = response as? HTTPURLResponse {
                    print("Health check response on port \(port): \(httpResponse.statusCode)")
                    if httpResponse.statusCode == 200 {
                        self?.isBackendRunning = true
                        self?.backendStatus = "Running on port \(port)"
                        print("Backend is healthy on port \(port)")
                    } else {
                        self?.isBackendRunning = false
                        self?.backendStatus = "Backend returned status \(httpResponse.statusCode) on port \(port)"
                    }
                } else {
                    print("Health check: No response received on port \(port)")
                    self?.isBackendRunning = false
                    self?.backendStatus = "No response from backend"
                }
            }
        }.resume()
    }
    
    private func tryHealthCheckOnPort(_ port: Int) {
        guard let url = URL(string: "http://localhost:\(port)/api/v1/health") else { return }
        checkHealthAtURL(url, port: port)
    }
    
    func getBackendPath() -> String {
        return backendPath
    }
    
    func isBackendDirectoryValid() -> Bool {
        let fileManager = FileManager.default
        let requirementsPath = backendPath + "/requirements.txt"
        let runApiPath = backendPath + "/run_api.py"
        let apiServerPath = backendPath + "/api_server.py"
        
        // Check for either run_api.py or api_server.py (both serve as entry points)
        let hasValidEntryPoint = fileManager.fileExists(atPath: runApiPath) || 
                                fileManager.fileExists(atPath: apiServerPath)
        
        return fileManager.fileExists(atPath: requirementsPath) && hasValidEntryPoint
    }
    
    deinit {
        stopBackend()
    }
}