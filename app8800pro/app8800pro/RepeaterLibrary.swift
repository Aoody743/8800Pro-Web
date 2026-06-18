import Foundation

enum RepeaterLibraryLoader {
    static func loadPackagedLibrary() async throws -> RepeaterLibraryPackage {
        guard let url = Bundle.main.url(forResource: "hamcq-repeaters", withExtension: "json") else {
            throw NSError(
                domain: "RepeaterLibrary",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "未找到内置 HamCQ 中继台库"]
            )
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(RepeaterLibraryPackage.self, from: data)
    }
}
