import Foundation

enum ServiceVisitCompletion {
    static func completeVisit(_ visit: ServiceVisitEntity, completedAt: Date, completedOdometer: Int) {
        visit.isCompleted = true
        visit.completedAt = completedAt
        visit.completedOdometer = completedOdometer
        for task in visit.tasks where task.isApplicable && task.isMandatory {
            task.isDone = true
            task.doneAt = completedAt
            task.doneOdometer = completedOdometer
        }
    }

    static func reopenVisit(_ visit: ServiceVisitEntity) {
        visit.isCompleted = false
        visit.completedAt = nil
        visit.completedOdometer = nil
        for task in visit.tasks where task.isApplicable {
            task.isDone = false
            task.doneAt = nil
            task.doneOdometer = nil
        }
    }

    static func markTaskUndone(_ task: ServiceTaskEntity, visit: ServiceVisitEntity) {
        task.isDone = false
        task.doneAt = nil
        task.doneOdometer = nil
        if visit.isCompleted {
            reopenVisit(visit)
        }
    }

    static func markTaskDone(_ task: ServiceTaskEntity, visit: ServiceVisitEntity, odometerKm: Int) {
        task.isDone = true
        task.doneAt = Date()
        task.doneOdometer = odometerKm
    }
}
