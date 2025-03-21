import Foundation

/// Represents a Kubernetes context.
struct KubernetesContext: Identifiable, Equatable, Hashable {
    /// The context name
    let name: String

    /// The cluster name
    let cluster: String

    /// Whether this context is the active one
    let isActive: Bool

    /// Whether this context is considered stable
    let isStable: Bool

    /// When the context was last updated
    let lastUpdated: Date

    /// The namespace, if specified
    let namespace: String?

    init(name: String,
         cluster: String,
         isActive: Bool,
         isStable: Bool,
         lastUpdated: Date = Date(),
         namespace: String? = nil) {
        self.name = name
        self.cluster = cluster
        self.isActive = isActive
        self.isStable = isStable
        self.lastUpdated = lastUpdated
        self.namespace = namespace
    }

    // Conform to Identifiable with name as id
    var id: String { name }

    // Conform to Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(cluster)
        hasher.combine(isActive)
    }

    // Conform to Equatable
    static func == (lhs: KubernetesContext, rhs: KubernetesContext) -> Bool {
        return lhs.name == rhs.name &&
               lhs.cluster == rhs.cluster &&
               lhs.isActive == rhs.isActive &&
               lhs.isStable == rhs.isStable
    }

    /// Create a copy of this context with updated properties
    func with(
        name: String? = nil,
        cluster: String? = nil,
        isActive: Bool? = nil,
        isStable: Bool? = nil,
        lastUpdated: Date? = nil,
        namespace: String? = nil
    ) -> KubernetesContext {
        return KubernetesContext(
            name: name ?? self.name,
            cluster: cluster ?? self.cluster,
            isActive: isActive ?? self.isActive,
            isStable: isStable ?? self.isStable,
            lastUpdated: lastUpdated ?? self.lastUpdated,
            namespace: namespace ?? self.namespace
        )
    }
}