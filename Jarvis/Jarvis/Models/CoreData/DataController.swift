import CoreData
import Foundation

class DataController: ObservableObject {
    let container: NSPersistentContainer
    
    init() {
        container = NSPersistentContainer(name: "Jarvis")
        
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        
        // Enable automatic merging of changes
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    // MARK: - Save Context
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Error saving context: \(error)")
            }
        }
    }
    
    // MARK: - Delete Context
    func delete(_ object: NSManagedObject) {
        let context = container.viewContext
        context.delete(object)
        save()
    }
    
    // MARK: - Batch Operations
    func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) -> T) async -> T {
        await container.performBackgroundTask { context in
            block(context)
        }
    }
    
    // MARK: - Preview Helper
    static var preview: DataController = {
        let controller = DataController(inMemory: true)
        let viewContext = controller.container.viewContext
        
        // Create sample data for previews
        let sampleChat = Chat(context: viewContext)
        sampleChat.id = UUID()
        sampleChat.title = "Sample Chat"
        sampleChat.createdAt = Date()
        sampleChat.isActive = true
        
        let sampleMessage1 = Message(context: viewContext)
        sampleMessage1.id = UUID()
        sampleMessage1.content = "Hello, how can I help you today?"
        sampleMessage1.isUser = false
        sampleMessage1.timestamp = Date()
        sampleMessage1.chat = sampleChat
        
        let sampleMessage2 = Message(context: viewContext)
        sampleMessage2.id = UUID()
        sampleMessage2.content = "I need help with my project"
        sampleMessage2.isUser = true
        sampleMessage2.timestamp = Date().addingTimeInterval(60)
        sampleMessage2.chat = sampleChat
        
        do {
            try viewContext.save()
        } catch {
            print("Error creating preview data: \(error)")
        }
        
        return controller
    }()
    
    // MARK: - In-Memory Initializer for Testing
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Jarvis")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
} 