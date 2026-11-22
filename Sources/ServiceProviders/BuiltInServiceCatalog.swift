import Foundation

enum BuiltInServiceCatalog {
    static let definitions: [ServiceDefinition] = [
        service(.aircall, "Aircall", "https://status.aircall.com/"),
        service(.bigcommerce, "BigCommerce", "https://status.bigcommerce.com/"),
        service(.canva, "Canva", "https://www.canvastatus.com/"),
        service(.cloudflare, "Cloudflare", "https://www.cloudflarestatus.com/"),
        service(.cloudways, "Cloudways", "https://status.cloudways.com/"),
        service(.github, "GitHub", "https://www.githubstatus.com/"),
        service(.hubspot, "HubSpot", "https://status.hubspot.com/"),
        service(.mongodb, "MongoDB", "https://status.mongodb.com/"),
        service(.monday, "Monday", "https://status.monday.com/"),
        service(.ngrok, "ngrok", "https://status.ngrok.com/"),
        service(.openai, "OpenAI", "https://status.openai.com/"),
        service(.register, "Register.it", "https://status.register.it/"),
        service(.paypal, "PayPal", "https://paypal-status.com/product/production"),
        service(.slack, "Slack", "https://slack-status.com/"),
        service(.stripe, "Stripe", "https://www.stripestatus.com/"),
        service(.vercel, "Vercel", "https://www.vercel-status.com/")
    ]

    static func definition(for id: ServiceID) -> ServiceDefinition? {
        definitions.first { $0.id == id }
    }

    private static func service(
        _ id: ServiceID,
        _ displayName: String,
        _ statusPage: String
    ) -> ServiceDefinition {
        ServiceDefinition(
            id: id,
            displayName: displayName,
            statusPageURL: validatedHTTPSURL(statusPage),
            attribution: ProviderAttribution(publisherName: displayName)
        )
    }

    private static func validatedHTTPSURL(_ value: String) -> URL {
        guard let url = URL(string: value),
              url.scheme == "https",
              url.host != nil else {
            preconditionFailure("Invalid built-in status page URL: \(value)")
        }

        return url
    }
}
