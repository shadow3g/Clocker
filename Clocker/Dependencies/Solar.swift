// Copyright © 2015 Abhishek Banthia

import Cocoa
import CoreLocation

public struct Solar {
    /// The coordinate that is used for the calculation
    public let coordinate: CLLocationCoordinate2D

    /// The date to generate sunrise / sunset times for
    public private(set) var date: Date

    public private(set) var sunrise: Date?
    public private(set) var sunset: Date?
    public private(set) var civilSunrise: Date?
    public private(set) var civilSunset: Date?
    public private(set) var nauticalSunrise: Date?
    public private(set) var nauticalSunset: Date?
    public private(set) var astronomicalSunrise: Date?
    public private(set) var astronomicalSunset: Date?

    // MARK: Init

    public init?(for date: Date = Date(), coordinate: CLLocationCoordinate2D) {
        self.date = date

        guard CLLocationCoordinate2DIsValid(coordinate) else {
            return nil
        }

        self.coordinate = coordinate

        // Fill this Solar object with relevant data
        calculate()
    }

    // MARK: - Public functions

    /// Sets all of the Solar object's sunrise / sunset variables, if possible.
    /// - Note: Can return `nil` objects if sunrise / sunset does not occur on that day.
    public mutating func calculate() {
        sunrise = calculate(.sunrise, for: date, and: .official)
        sunset = calculate(.sunset, for: date, and: .official)
        civilSunrise = calculate(.sunrise, for: date, and: .civil)
        civilSunset = calculate(.sunset, for: date, and: .civil)
        nauticalSunrise = calculate(.sunrise, for: date, and: .nautical)
        nauticalSunset = calculate(.sunset, for: date, and: .nautical)
        astronomicalSunrise = calculate(.sunrise, for: date, and: .astronimical)
        astronomicalSunset = calculate(.sunset, for: date, and: .astronimical)
    }

    // MARK: - Private functions

    private enum SunriseSunset {
        case sunrise
        case sunset
    }

    /// Used for generating several of the possible sunrise / sunset times
    private enum Zenith: Double {
        case official = 90.83
        case civil = 96
        case nautical = 102
        case astronimical = 108
    }

    private func calculate(_ sunriseSunset: SunriseSunset, for date: Date, and zenith: Zenith) -> Date? {
        guard let utcTimezone = TimeZone(identifier: "UTC") else { return nil }

        // Get the day of the year
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utcTimezone
        guard let dayInt = calendar.ordinality(of: .day, in: .year, for: date) else { return nil }
        let day = Double(dayInt)

        // Convert longitude to hour value and calculate an approx. time
        let lngHour = coordinate.longitude / 15

        let hourTime: Double = sunriseSunset == .sunrise ? 6 : 18
        let time = day + ((hourTime - lngHour) / 24)

        // Calculate the suns mean anomaly
        let meanAnomaly = (0.9856 * time) - 3.289

        // Calculate the sun's true longitude
        let subexpression1 = 1.916 * sin(meanAnomaly.degreesToRadians)
        let subexpression2 = 0.020 * sin(2 * meanAnomaly.degreesToRadians)
        var longitude = meanAnomaly + subexpression1 + subexpression2 + 282.634

        // Normalise L into [0, 360] range
        longitude = normalise(longitude, withMaximum: 360)

        // Calculate the Sun's right ascension
        var rightAscenscion = atan(0.91764 * tan(longitude.degreesToRadians)).radiansToDegrees

        // Normalise RA into [0, 360] range
        rightAscenscion = normalise(rightAscenscion, withMaximum: 360)

        // Right ascension value needs to be in the same quadrant as L...
        let leftQuadrant = floor(longitude / 90) * 90
        let rightQuadrant = floor(rightAscenscion / 90) * 90
        rightAscenscion += (leftQuadrant - rightQuadrant)

        // Convert RA into hours
        rightAscenscion /= 15

        // Calculate Sun's declination
        let sinDec = 0.39782 * sin(longitude.degreesToRadians)
        let cosDec = cos(asin(sinDec))

        // Calculate the Sun's local hour angle
        let cosH = (cos(zenith.rawValue.degreesToRadians) - (sinDec * sin(coordinate.latitude.degreesToRadians))) / (cosDec * cos(coordinate.latitude.degreesToRadians))

        // No sunrise
        guard cosH < 1 else {
            return nil
        }

        // No sunset
        guard cosH > -1 else {
            return nil
        }

        // Finish calculating H and convert into hours
        let tempH = sunriseSunset == .sunrise ? 360 - acos(cosH).radiansToDegrees : acos(cosH).radiansToDegrees
        let hours = tempH / 15.0

        // Calculate local mean time of rising
        let localMeanRisingTime = hours + rightAscenscion - (0.06571 * time) - 6.622

        // Adjust time back to UTC
        var utcCompatibleTime = localMeanRisingTime - lngHour

        // Normalise UT into [0, 24] range
        utcCompatibleTime = normalise(utcCompatibleTime, withMaximum: 24)

        // Calculate all of the sunrise's / sunset's date components
        let hour = floor(utcCompatibleTime)
        let minute = floor((utcCompatibleTime - hour) * 60.0)
        let second = (((utcCompatibleTime - hour) * 60) - minute) * 60.0

        let shouldBeYesterday = lngHour > 0 && utcCompatibleTime > 12 && sunriseSunset == .sunrise
        let shouldBeTomorrow = lngHour < 0 && utcCompatibleTime < 12 && sunriseSunset == .sunset

        let setDate: Date
        if shouldBeYesterday {
            setDate = Date(timeInterval: -(60 * 60 * 24), since: date)
        } else if shouldBeTomorrow {
            setDate = Date(timeInterval: 60 * 60 * 24, since: date)
        } else {
            setDate = date
        }

        var components = calendar.dateComponents([.day, .month, .year], from: setDate)
        components.hour = Int(hour)
        components.minute = Int(minute)
        components.second = Int(second)

        calendar.timeZone = utcTimezone
        return calendar.date(from: components)
    }

    /// Normalises a value between 0 and `maximum`, by adding or subtracting `maximum`
    private func normalise(_ value: Double, withMaximum maximum: Double) -> Double {
        var value = value

        if value < 0 {
            value += maximum
        }

        if value > maximum {
            value -= maximum
        }

        return value
    }
}

extension Solar {
    /// Whether the location specified by the `latitude` and `longitude` is in daytime on `date`
    /// - Complexity: O(1)
    public var isDaytime: Bool {
        guard
            let sunrise = sunrise,
            let sunset = sunset
        else {
            return false
        }

        let beginningOfDay = sunrise.timeIntervalSince1970
        let endOfDay = sunset.timeIntervalSince1970
        let currentTime = date.timeIntervalSince1970

        let isSunriseOrLater = currentTime >= beginningOfDay
        let isBeforeSunset = currentTime < endOfDay

        return isSunriseOrLater && isBeforeSunset
    }

    /// Whether the location specified by the `latitude` and `longitude` is in nighttime on `date`
    /// - Complexity: O(1)
    public var isNighttime: Bool {
        return !isDaytime
    }
}

// MARK: - Helper extensions

private extension Double {
    var degreesToRadians: Double {
        return Double(self) * (Double.pi / 180.0)
    }

    var radiansToDegrees: Double {
        return (Double(self) * 180.0) / Double.pi
    }
}
