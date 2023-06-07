import Foundation
import XMLCoder

extension GtkCodeGen {
    static func decodeGIR(_ data: Data) throws -> GIR {
        let decoder = XMLDecoder()
        decoder.keyDecodingStrategy = .custom({ path in
            let codingKey = path[path.count - 1]
            let containsColon = codingKey.stringValue.contains(":")
            let containsHyphen = codingKey.stringValue.contains("-")
            if containsColon || containsHyphen {
                var input = codingKey.stringValue
                var output = ""

                // Remove namespace
                if containsColon {
                    let parts = input.split(separator: ":").map(String.init)
                    output = parts[0]
                    input = parts[1]
                }

                // Convert kebab-case to camelCase
                if containsHyphen {
                    var parts = input.split(separator: "-")
                    let firstPart = String(parts.removeFirst())
                    if containsColon {
                        output += firstPart.capitalized
                    } else {
                        output += firstPart
                    }

                    for part in parts {
                        output += part.capitalized
                    }
                } else {
                    output += input.capitalized
                }

                return output
            } else {
                return codingKey
            }
        })
        return try decoder.decode(GIR.self, from: data)
    }
}

struct GIR: Decodable {
    var package: Package
    var namespace: Namespace
    var include: [Include]
}

struct Namespace: Decodable {
    var name: String
    var version: String
    var sharedLibrary: String
    var cIdentifierPrefix: String
    var cSymbolPrefix: String

    var aliases: [Alias]
    var classes: [Class]
    var enumerations: [Enumeration]
    var interfaces: [Interface]

    enum CodingKeys: String, CodingKey {
        case name, version, sharedLibrary
        case cIdentifierPrefix = "cIdentifierPrefixes"
        case cSymbolPrefix = "cSymbolPrefixes"
        case aliases = "alias"
        case classes = "class"
        case enumerations = "enumeration"
        case interfaces = "interface"
    }
}

/// Can be expanded in future. Intended to be a common API for classes and interfaces.
protocol ClassLike {
    var name: String { get }
    var cSymbolPrefix: String { get }
    var methods: [Method] { get }
    var signals: [Signal] { get }
    var properties: [Property] { get }
}

struct Interface: Decodable, ClassLike {
    var name: String
    var cSymbolPrefix: String
    var cType: String
    var glibTypeName: String
    var glibGetType: String
    var glibTypeStruct: String?
    var doc: String
    var prerequisites: [ConformancePrerequisite]

    var functions: [Function]
    var virtualMethods: [VirtualMethod]
    var methods: [Method]
    var signals: [Signal]
    var properties: [Property]

    enum CodingKeys: String, CodingKey {
        case name, cSymbolPrefix, cType, glibTypeName, glibGetType, glibTypeStruct, doc
        case prerequisites = "prerequisite"
        case functions = "function"
        case virtualMethods = "virtualMethod"
        case methods = "method"
        case signals = "glibSignal"
        case properties = "property"
    }
}

struct Function: Decodable {
    var name: String
    var cIdentifier: String
    var doc: String?
    var returnValue: ReturnValue
    var parameters: Parameters

    enum CodingKeys: String, CodingKey {
        case name, cIdentifier, doc, returnValue, parameters
    }
}

struct VirtualMethod: Decodable {
    var name: String
    var invoker: String?
    var attribute: VirtualMethodAttribute?
    var doc: String?
    var returnValue: ReturnValue
    var parameters: MethodParameters
}

struct VirtualMethodAttribute: Decodable {
    var name: String
    var value: String
}

struct ConformancePrerequisite: Decodable {
    var name: String
}

struct Enumeration: Decodable {
    var name: String
    var version: String?
    var cType: String
    var doc: String?
    var members: [Member]

    enum CodingKeys: String, CodingKey {
        case name, cType, doc, version
        case members = "member"
    }

    struct Member: Decodable {
        var name: String
        var cIdentifier: String
        var doc: String
    }
}

struct Alias: Decodable {
    var name: String
    @Attribute var cType: String
    var doc: String
    @Element var type: String
}

struct Class: Decodable, ClassLike {
    var name: String
    var cSymbolPrefix: String
    var cType: String?
    var parent: String?
    var abstract: Bool?

    var doc: String
    var constructors: [Constructor]
    var methods: [Method]
    var properties: [Property]
    var signals: [Signal]
    var conformances: [Conformance]

    enum CodingKeys: String, CodingKey {
        case name, cSymbolPrefix, cType, parent, abstract, doc
        case constructors = "constructor"
        case methods = "method"
        case properties = "property"
        case signals = "glibSignal"
        case conformances = "implements"
    }

    /// Aggregates all members of a specific type including those inherited from implemented
    /// interfaces (but not those from super classes).
    func getAll<T>(
        _ keyPath: KeyPath<ClassLike, [T]>,
        namespace: Namespace
    ) -> [(any ClassLike, T)] {
        let baseProperties = self[keyPath: keyPath].map { (self, $0) }
        let interfaceProperties = getImplementedInterfaces(namespace: namespace)
            .flatMap { interface in
                let elements = interface[keyPath: keyPath]
                return elements.map { (interface, $0) }
            }
        return baseProperties + interfaceProperties
    }

    /// Returns all interfaces implemented by the class. Excludes interfaces that can't
    /// be found in the namespace.
    func getImplementedInterfaces(namespace: Namespace) -> [Interface] {
        conformances.compactMap { conformance in
            namespace.interfaces.first { $0.name == conformance.name }
        }
    }
}

struct Conformance: Decodable {
    var name: String
}

struct Signal: Decodable {
    var name: String
    var when: String
    var noRecurse: Bool?
    var doc: String?
    var returnValue: ReturnValue
    var parameters: Parameters?
}

struct Constructor: Decodable {
    var name: String
    var cIdentifier: String
    var doc: String
    var returnValue: ReturnValue
    var parameters: Parameters?
    var version: String?
}

struct Method: Decodable {
    var name: String
    var cIdentifier: String
    var version: String?
    var doc: String?
    var returnValue: ReturnValue?
    var parameters: MethodParameters?
}

struct Property: Decodable {
    var name: String
    var doc: String?
    var getter: String?
    var setter: String?
    var defaultValue: String?
    var transferOwnership: String
    var writable: Bool?
    var type: GIRType?
}

struct MethodParameters: Decodable {
    var instanceParameter: Parameter
    var parameters: [Parameter]

    enum CodingKeys: String, CodingKey {
        case instanceParameter
        case parameters = "parameter"
    }
}

struct Parameters: Decodable {
    var parameters: [Parameter]

    enum CodingKeys: String, CodingKey {
        case parameters = "parameter"
    }
}

struct Parameter: Decodable {
    var nullable: Bool?
    var name: String
    var transferOwnership: String
    var doc: String?
    var type: GIRType?
    var varargs: VarArgs?
}

struct VarArgs: Decodable {}

struct ReturnValue: Decodable {
    var nullable: Bool?
    var transferOwnership: String?
    var doc: String?
    var type: GIRType?
}

struct GIRType: Decodable {
    var name: String?
    var cType: String?
}

struct Package: Decodable {
    var name: String
}

struct Include: Decodable {
    var name: String
    var version: String
}