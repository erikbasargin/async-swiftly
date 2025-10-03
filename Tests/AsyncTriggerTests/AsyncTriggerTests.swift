import AsyncTrigger
import Testing
import TestingSupport

struct AsyncTriggerTests {
    
    @Test func `Trigger resumes consumers when fire is called`() async throws {
        let trigger = AsyncTrigger()
        
        async let work1 = trigger()
        async let work2 = trigger()
        
        trigger.fire()
        
        await #expect((work1, work2) == (.triggered, .triggered))
    }
    
    @Test func `Trigger resumes consumers immediately given trigger is fired`() async throws {
        let trigger = AsyncTrigger()
        trigger.fire()
        
        async let work1 = trigger()
        async let work2 = trigger()
        
        await #expect((work1, work2) == (.triggered, .triggered))
    }
    
    @Test func `Trigger consumer resumes when task is cancelled`() async throws {
        let trigger = AsyncTrigger()
        let work = Task(operation: trigger.callAsFunction)
        
        work.cancel()
        
        await #expect(work.value == .cancelled)
    }
    
    @Test func `Trigger is async sequence`() async throws {
        let trigger = AsyncTrigger()
        
        async let work = trigger.collect()
        
        trigger.fire()
        
        await #expect(work == [.triggered])
    }
}
