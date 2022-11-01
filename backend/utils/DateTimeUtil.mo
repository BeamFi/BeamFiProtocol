// Original source - https://github.com/caya-ventures/mofram-lib/blob/main/src/DateTime.mo

import Int "mo:base/Int";
import Time "mo:base/Time";

import TextUtil "../utils/TextUtil"

module DateTimeUtil {

  public type Year = Int;
  public type Month = Int;
  public type Day = Int;
  public type DayOfWeek = {
    #Sunday;
    #Monday;
    #Tuesday;
    #Wednesday;
    #Thursday;
    #Friday;
    #Saturday
  };

  public type Hour = Int;
  public type Minute = Int;
  public type Second = Int;
  public type DateTime = {
    year : Year;
    month : Month;
    day : Day;
    week_day : DayOfWeek;
    hour : Hour;
    min : Minute;
    sec : Second
  };

  // Convert weekday (0-6) to human readable value.
  public func weekDayToHumanReadable(weekDay : Nat) : DayOfWeek {
    switch (weekDay) {
      case 0 #Sunday;
      case 1 #Monday;
      case 2 #Tuesday;
      case 3 #Wednesday;
      case 4 #Thursday;
      case 5 #Friday;
      case _ #Saturday
    }
  };

  // Convert weekday from human readable to a 0-6 value.
  public func weekDayFromHumanReadable(weekDay : DayOfWeek) : Nat {
    switch (weekDay) {
      case (#Sunday) 0;
      case (#Monday) 1;
      case (#Tuesday) 2;
      case (#Wednesday) 3;
      case (#Thursday) 4;
      case (#Friday) 5;
      case (#Saturday) 6
    }
  };

  // Convert date and time in DateTime object to timestamp in nanoseconds.
  public func dateTimeToTimestamp(dateTime : DateTime) : Int {
    var days : Int = yearsToDays(dateTime.year);
    days += daysFromYearStart(isLeapYear(dateTime.year), dateTime.month);
    days += dateTime.day - 1;

    return timeToTimestamp(dateTime) + daysToTimestamp(days)
  };

  // Convert years into days starting from 1970.
  private func yearsToDays(year : Year) : Int {
    365 * (year - 1970) + (year - 1969) / 4 - (year - 1901) / 100 + (year - 1601) / 400
  };

  // Check wether year is a leap year.
  public func isLeapYear(year : Year) : Bool {
    year % 4 == 0 and year % 100 != 0 or year % 400 == 0
  };

  // Get number of days passed from 1 Jan for given month.
  private func daysFromYearStart(isLeapYear : Bool, month : Month) : Int {
    if (isLeapYear) {
      switch (month) {
        case (1) 0;
        case (2) 31;
        case (3) 60;
        case (4) 91;
        case (5) 121;
        case (6) 152;
        case (7) 182;
        case (8) 213;
        case (9) 244;
        case (10) 274;
        case (11) 305;
        case (12) 335;
        case (_) 0
      }
    } else {
      switch (month) {
        case (1) 0;
        case (2) 31;
        case (3) 59;
        case (4) 90;
        case (5) 120;
        case (6) 151;
        case (7) 181;
        case (8) 212;
        case (9) 243;
        case (10) 273;
        case (11) 304;
        case (12) 334;
        case (_) 0
      }
    }
  };

  // Convert hours, minutes, seconds from DateTime object into timestamp.
  public func timeToTimestamp(time : DateTime) : Time.Time {
    ((time.hour * 3600) + (time.min * 60) + time.sec) * 1000000000
  };

  // Convert days into timestamp.
  public func daysToTimestamp(days : Int) : Time.Time {
    days * 24 * 3600 * 1000000000
  };

  // Convert timestamp in nanoseconds into DateTime object.
  public func timestampToDateTime(nsTimestamp : Time.Time) : DateTime {
    let timestamp : Int = nsTimestamp / 1000000000;
    // Number of days in month in normal year
    let daysOfMonth : [Int] = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    var currentYear : Int = 1970;
    var daysTillNow : Int = Int.div(timestamp, (24 * 60 * 60));
    var extraTime : Int = Int.rem(timestamp, (24 * 60 * 60));
    var extraDays : Int = 0;
    var index : Nat = 0;
    var date : Int = 0;
    var month : Nat = 0;
    var hours : Int = 0;
    var minutes : Int = 0;
    var seconds : Int = 0;
    var flag : Int = 0;

    // Calculate current year
    while (daysTillNow >= 365) {
      if (
        Int.equal(Int.rem(currentYear, 400), 0) or (
          Int.equal(Int.rem(currentYear, 4), 0) and Int.notEqual(Int.rem(currentYear, 100), 0)
        )
      ) {
        daysTillNow := daysTillNow - 366
      } else {
        daysTillNow := daysTillNow - 365
      };

      if (daysTillNow > 0) {
        currentYear += 1
      }
    };

    // daysTillNow contains a previous day value so update it with current day
    extraDays := daysTillNow + 1;
    if (
      Int.equal(Int.rem(currentYear, 400), 0) or (
        Int.equal(Int.rem(currentYear, 4), 0) and Int.notEqual(Int.rem(currentYear, 100), 0)
      )
    ) {
      flag := 1
    };

    // Calculate month and date
    if (flag == 1) {
      label monthDate while (true) {
        if (index == 1) {
          if (extraDays - 29 < 0) {
            break monthDate
          };
          month += 1;
          extraDays := extraDays - 29
        } else {
          if (extraDays - daysOfMonth[index] <= 0) {
            break monthDate
          };
          month += 1;
          extraDays := extraDays - daysOfMonth[index]
        };
        index += 1
      }
    } else {
      label monthDate while (true) {
        if (extraDays - daysOfMonth[index] <= 0) {
          break monthDate
        };
        month += 1;
        extraDays := extraDays - daysOfMonth[index];
        index += 1
      }
    };

    // Current Month
    if (extraDays > 0) {
      month += 1;
      date := extraDays
    } else {
      if (month == 2 and flag == 1) {
        date := 29
      } else if (extraDays == 0 and month == 0) {
        month := 12;
        date := 31
      } else {
        date := daysOfMonth[month - 1]
      }
    };

    let timestampDay = Int.div(timestamp, 86400);
    let weekDay = switch (1 + (timestampDay + 4) % 7) {
      case 1 #Sunday;
      case 2 #Monday;
      case 3 #Tuesday;
      case 4 #Wednesday;
      case 5 #Thursday;
      case 6 #Friday;
      case _ #Saturday
    };

    hours := Int.div(extraTime, 3600);
    minutes := Int.div(Int.rem(extraTime, 3600), 60);
    seconds := Int.rem(Int.rem(extraTime, 3600), 60);

    {
      year = currentYear;
      month = month;
      day = date;
      week_day = weekDay;
      hour = hours;
      min = minutes;
      sec = seconds
    }
  };

  public func dateToCalendarDayText(time : Time.Time) : Text {
    let dateTime = timestampToDateTime(time);
    let monthStr = TextUtil.padStart(Int.toText(dateTime.month), 2, "0");
    let dayStr = TextUtil.padStart(Int.toText(dateTime.day), 2, "0");

    Int.toText(dateTime.year) # monthStr # dayStr
  };

}
