import AsyncTrigger
import Testing
import TestingSupport

struct AsyncTriggerTests {
    
    @Test func trigger_resumes_consumers_when_fire_is_called() async throws {
        let trigger = AsyncTrigger()
        
        async let work1 = trigger()
        async let work2 = trigger()
        
        trigger.fire()
        
        await #expect((work1, work2) == (.triggered, .triggered))
    }
    
    @Test func trigger_resumes_consumers_immediately_given_trigger_is_fired() async throws {
        let trigger = AsyncTrigger()
        trigger.fire()
        
        async let work1 = trigger()
        async let work2 = trigger()
        
        await #expect((work1, work2) == (.triggered, .triggered))
    }
    
    @Test func trigger_consumer_resumes_when_task_is_cancelled() async throws {
        let trigger = AsyncTrigger()
        let work = Task(operation: trigger.callAsFunction)
        
        work.cancel()
        
        await #expect(work.value == .cancelled)
    }
    
    @Test func trigger_is_async_sequence() async throws {
        let trigger = AsyncTrigger()
        
        async let work = trigger.collect()
        
        trigger.fire()
        
        await #expect(work == [.triggered])
    }
}
