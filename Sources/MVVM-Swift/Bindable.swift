//
//  Bindable.swift
//
//  Created by Alexander Karpov on 13.02.2020.
//  Copyright © 2020 Alexander Karpov. All rights reserved.
//

/**
 This new type will enable any value to be bound to any UI property, without requiring specific abstractions to be built for each model. Let’s start by declaring Bindable and defining properties to keep track of all of its observations, and to enable it to cache the latest value that passed through it.
 
 Instead of requiring each view controller to observe its model and to define explicit rules as to how each update should be handled, the idea behind value binding is to enable us to write auto-updating UI code by simply associating each piece of model data with a UI property, in a much more declarative fashion.
 
 implemented under guide: https://www.swiftbysundell.com/articles/bindable-values-in-swift/
 */
class Bindable<Value> {
    private var observations = [(Value) -> Bool]()
    private var lastValue: Value?

    init(_ value: Value? = nil) {
        lastValue = value
    }
}
/**
 Next, let’s enable Bindable to be observed, just like UserHolder before it — but with the key difference that we’ll keep the observation method private:
 */
private extension Bindable {
    func addObservation<O: AnyObject>(
        for object: O,
        handler: @escaping (O, Value) -> Void
    ) {
        // If we already have a value available, we'll give the
        // handler access to it directly.
        lastValue.map { handler(object, $0) }

        // Each observation closure returns a Bool that indicates
        // whether the observation should still be kept alive,
        // based on whether the observing object is still retained.
        observations.append { [weak object] value in
            guard let object = object else {
                return false
            }

            handler(object, value)
            return true
        }
    }
}
/**
 Finally, we need a way to update a Bindable instance whenever a new model became available. For that we’ll add an update method that updates the bindable’s lastValue and calls each observation through filter, in order to remove all observations that have become outdated:
 */
extension Bindable {
    func update(with value: Value) {
        lastValue = value
        observations = observations.filter { $0(value) }
    }
}
/**
 #Binding values

 So far we’ve defined all of the underlying infrastructure that we’ll need in order to actually start binding values to our UI — but to do that, we need an API to call. The reason we kept addObservation private before, is that we’ll instead expose a KeyPath-based API that we’ll be able to use to directly associate each model property with its corresponding UI property.
 Like we took a look at in “The power of key paths in Swift”, key paths can enable us to construct some really nice APIs that give us dynamic access to an object’s properties, without having to use closures. Let’s start by extending Bindable with an API that’ll let us bind a key path from a model to a key path of a view:
 */
extension Bindable {
    func bind<O: AnyObject, T>(
        _ sourceKeyPath: KeyPath<Value, T>,
        to object: O,
        _ objectKeyPath: ReferenceWritableKeyPath<O, T>
    ) {
        addObservation(for: object) { object, observed in
            let value = observed[keyPath: sourceKeyPath]
            object[keyPath: objectKeyPath] = value
        }
    }
}
/**
 Since we’ll sometimes want to bind values to an optional property (such as text on UILabel), we’ll also need an additional bind overload that accepts an objectKeyPath for an optional of T:
 */
extension Bindable {
    func bind<O: AnyObject, T>(
        _ sourceKeyPath: KeyPath<Value, T>,
        to object: O,
        // This line is the only change compared to the previous
        // code sample, since the key path we're binding *to*
        // might contain an optional.
        _ objectKeyPath: ReferenceWritableKeyPath<O, T?>
    ) {
        addObservation(for: object) { object, observed in
            let value = observed[keyPath: sourceKeyPath]
            object[keyPath: objectKeyPath] = value
        }
    }
}
/**
 #Transforms

 So far, all of our model properties have been of the same type as their UI counterparts, but that’s not always the case. For example, in our earlier implementation we had to convert the user’s followersCount property to a string, in order to be able to render it using a UILabel — so how can we achieve the same thing with our new value binding approach?
 One way to do just that would be to introduce yet another bind overload that adds a transform parameter, containing a function that converts a value of T into the required result type R — and to then use that function within our observation to perform the conversion, like this:
 */
extension Bindable {
    func bind<O: AnyObject, T, R>(
        _ sourceKeyPath: KeyPath<Value, T>,
        to object: O,
        _ objectKeyPath: ReferenceWritableKeyPath<O, R?>,
        transform: @escaping (T) -> R?
    ) {
        addObservation(for: object) { object, observed in
            let value = observed[keyPath: sourceKeyPath]
            let transformed = transform(value)
            object[keyPath: objectKeyPath] = transformed
        }
    }
}

struct User {}

class SyncService<Value> {
    func sync(then callback: (Value) -> Void) {}
}

class UserModelController {
    let user: Bindable<User>
    private let syncService: SyncService<User>

    init(user: User, syncService: SyncService<User>) {
        self.user = Bindable(user)
        self.syncService = syncService
    }

    func applicationDidBecomeActive() {
        syncService.sync(then: user.update)
    }
}
