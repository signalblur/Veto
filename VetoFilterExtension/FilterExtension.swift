import Foundation
import IdentityLookup
import VetoCore

final class FilterExtension: ILMessageFilterExtension {}

extension FilterExtension: ILMessageFilterQueryHandling {
    func handle(
        _ queryRequest: ILMessageFilterQueryRequest,
        context: ILMessageFilterExtensionContext
    ) async -> ILMessageFilterQueryResponse {
        let action = await ExtensionRuntime.shared.classify(
            sender: queryRequest.sender ?? "",
            body: queryRequest.messageBody ?? ""
        )
        let response = ILMessageFilterQueryResponse()
        response.action = action
        return response
    }
}
