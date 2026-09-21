/// Whether the car memory survives the process. Chosen by the composition root and read by features
/// that must warn about, or refuse, writes that would vanish.
enum PersistenceMode: Equatable, Sendable {
    case durable
    /// The on-disk store could not be opened; this session keeps data in memory only.
    case temporary
}
