CREATE TYPE ActivityType AS ENUM (
	'Strength training',
	'Cardio',
	'Yoga',
	'Dance',
	'Injury rehabilitation'
);

CREATE TYPE Gender AS ENUM (
	'Male',
	'Female',
	'Unknown',
	'Other'
);

CREATE TYPE TrainerType AS ENUM (
	'Head trainer',
	'Assistant trainer'
);

CREATE TYPE DayOfTheWeek AS ENUM (
	'Monday',
	'Tuesday',
	'Wednesday',
	'Thursday',
	'Friday',
	'Saturday',
	'Sunday'
);

CREATE TABLE Countries (
	CountryId SERIAL PRIMARY KEY,
	Name VARCHAR(50) UNIQUE NOT NULL,
	Population INT NOT NULL CHECK (Population > 0),
	AverageSalary DECIMAL(10,2) NOT NULL CHECK (AverageSalary > 0)
);

CREATE TABLE FitnessCenters (
	FitnessCenterId SERIAL PRIMARY KEY,
	Name VARCHAR(50) NOT NULL,
	CountryId INT REFERENCES Countries(CountryId) NOT NULL
);

CREATE TABLE FitnessCenterWorkSchedules (
	FitnessCenterWorkScheduleId SERIAL PRIMARY KEY,
	FitnessCenterId INT NOT NULL REFERENCES FitnessCenters(FitnessCenterId),
	Day DayOfTheWeek NOT NULL,
	StartTime Time NOT NULL,
	EndTime Time NOT NULL CHECK (EndTime > StartTime),
	CONSTRAINT unique_day_schedule UNIQUE (FitnessCenterId, Day)
);

CREATE TABLE Participants (
	ParticipantId SERIAL PRIMARY KEY,
	FirstName VARCHAR(50) NOT NULL,
	LastName VARCHAR(50) NOT NULL,
	DateOfBirth DATE NOT NULL CHECK (DateOfBirth < CURRENT_DATE),
	Gender Gender NOT NULL,
	CountryId INT NOT NULL REFERENCES Countries(CountryId)
);

CREATE TABLE Trainers (
	TrainerId SERIAL PRIMARY KEY,
	FirstName VARCHAR(50) NOT NULL,
	LastName VARCHAR(50) NOT NULL,
	DateOfBirth DATE NOT NULL CHECK (DateOfBirth < CURRENT_DATE),
	Gender Gender NOT NULL,
	CountryId INT NOT NULL REFERENCES Countries(CountryId),
	FitnessCenterId INT NOT NULL REFERENCES FitnessCenters(FitnessCenterId)
);

CREATE TABLE Activities (
	ActivityId SERIAL PRIMARY KEY,
	NAME VARCHAR(50) NOT NULL,
	Type ActivityType NOT NULL
);

CREATE TABLE FitnessCenterActivities (
	FitnessCenterId INT NOT NULL REFERENCES FitnessCenters(FitnessCenterId),
	ActivityId INT NOT NULL REFERENCES Activities(ActivityId),
	MaxParticipants INT NOT NULL CHECK (MaxParticipants > 0),
	PricePerSession DECIMAL (10,2) NOT NULL CHECK (PricePerSession >= 0),
	PRIMARY KEY(FitnessCenterId, ActivityId)
);

CREATE TABLE FitnessCenterActivityTrainers (
	TrainerId INT NOT NULL REFERENCES Trainers(TrainerId) ON DELETE CASCADE,
	FitnessCenterId INT NOT NULL,
	ActivityId INT NOT NULL,
	TrainerType TrainerType NOT NULL,
	FOREIGN KEY (FitnessCenterId, ActivityId) REFERENCES FitnessCenterActivities(FitnessCenterId, ActivityId),
	PRIMARY KEY(FitnessCenterId, ActivityId, TrainerId)
);

CREATE TABLE FitnessCenterActivityParticipants (
	ParticipantId INT REFERENCES Participants(ParticipantId) NOT NULL,
	FitnessCenterId INT NOT NULL,
	ActivityId INT NOT NULL,
	FOREIGN KEY (FitnessCenterId, ActivityId) REFERENCES FitnessCenterActivities(FitnessCenterId, ActivityId),
	PRIMARY KEY(FitnessCenterId, ActivityId, ParticipantId)
);

CREATE TABLE FitnessCenterActivitySchedules (
	FitnessCenterScheduleId SERIAL PRIMARY KEY,
	FitnessCenterId INT NOT NULL,
	ActivityId INT NOT NULL,
	FOREIGN KEY (FitnessCenterId, ActivityId) REFERENCES FitnessCenterActivities(FitnessCenterId, ActivityId),
	ScheduleCode VARCHAR(20) UNIQUE NOT NULL,
	StartTime TIMESTAMP NOT NULL,
	EndTime TIMESTAMP NOT NULL CHECK (EndTime > StartTime)
);

CREATE TABLE SportEvents (
	SportEventId SERIAL PRIMARY KEY,
	Name VARCHAR(100) NOT NULL
);

CREATE TABLE FitnessCenterSportEvents (
	FitnessCenterId INT NOT NULL REFERENCES FitnessCenters(FitnessCenterId),
	SportEventId INT NOT NULL REFERENCES SportEvents(SportEventId),
	MaxParticipants INT NOT NULL CHECK (MaxParticipants > 0),
	StartTime TIMESTAMP NOT NULL,
	EndTime TIMESTAMP NOT NULL CHECK (EndTime > StartTime),
	PRIMARY KEY(FitnessCenterId, SportEventId)
);

CREATE TABLE FitnessCenterSportEventTrainers (
	SportEventId INT NOT NULL,
	FitnessCenterId INT NOT NULL,
	TrainerId INT NOT NULL REFERENCES Trainers(TrainerId),
	TrainerType TrainerType NOT NULL,
	FOREIGN KEY (SportEventId, FitnessCenterId) REFERENCES FitnessCenterSportEvents(SportEventId, FitnessCenterId),
	PRIMARY KEY(SportEventId, FitnessCenterId, TrainerId)
);

CREATE TABLE FitnessCenterSportEventParticipants (
	ParticipantId INT REFERENCES Participants(ParticipantId) NOT NULL,
	FitnessCenterId INT NOT NULL,
	SportEventId INT NOT NULL,
	FOREIGN KEY (FitnessCenterId, SportEventId) REFERENCES FitnessCenterSportEvents(FitnessCenterId, SportEventId),
	PRIMARY KEY(FitnessCenterId, SportEventId, ParticipantId)
);

CREATE OR REPLACE FUNCTION enforce_single_head_trainer()
RETURNS TRIGGER AS $$
BEGIN
    IF (SELECT COUNT(*) 
        FROM FitnessCenterActivityTrainers 
        WHERE ActivityId = NEW.ActivityId AND FitnessCenterId = NEW.FitnessCenterId AND TrainerType = 'Head trainer') >= 1
    THEN
        RAISE EXCEPTION 'Each activity can only have one head trainer';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER head_trainer_check
BEFORE INSERT OR UPDATE ON FitnessCenterActivityTrainers
FOR EACH ROW
WHEN (NEW.TrainerType = 'Head trainer')
EXECUTE FUNCTION enforce_single_head_trainer();

CREATE OR REPLACE FUNCTION enforce_activity_max_participants()
RETURNS TRIGGER AS $$
BEGIN
    IF (SELECT COUNT(*) 
        FROM FitnessCenterActivityParticipants 
        WHERE ActivityId = NEW.ActivityId AND FitnessCenterId = NEW.FitnessCenterId) >= 
        (SELECT MaxParticipants 
         FROM FitnessCenterActivities 
         WHERE ActivityId = NEW.ActivityId AND FitnessCenterId = NEW.FitnessCenterId)
    THEN
        RAISE EXCEPTION 'Maximum number of participants exceeded for this activity';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER activity_max_participants_check
BEFORE INSERT ON FitnessCenterActivityParticipants
FOR EACH ROW
EXECUTE FUNCTION enforce_activity_max_participants();

CREATE OR REPLACE FUNCTION enforce_event_max_participants()
RETURNS TRIGGER AS $$
BEGIN
    IF (SELECT COUNT(*) 
        FROM FitnessCenterSportEventParticipants 
        WHERE SportEventId = NEW.SportEventId AND FitnessCenterId = NEW.FitnessCenterId) >= 
        (SELECT MaxParticipants 
         FROM FitnessCenterSportEvents
         WHERE SportEventId = NEW.SportEventId AND FitnessCenterId = NEW.FitnessCenterId)
    THEN
        RAISE EXCEPTION 'Maximum number of participants exceeded for this sport event';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER event_max_participants_check
BEFORE INSERT ON FitnessCenterActivityParticipants
FOR EACH ROW
EXECUTE FUNCTION enforce_event_max_participants();

CREATE OR REPLACE FUNCTION enforce_head_trainer_limit()
RETURNS TRIGGER AS $$
BEGIN
    IF (SELECT COUNT(*) 
        FROM FitnessCenterActivityTrainers 
        WHERE TrainerId = NEW.TrainerId AND TrainerType = 'Head trainer') >= 2
    THEN
        RAISE EXCEPTION 'A trainer can be a head trainer for up to 2 activities';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER head_trainer_limit_check
BEFORE INSERT OR UPDATE ON FitnessCenterActivityTrainers
FOR EACH ROW
WHEN (NEW.TrainerType = 'Head trainer')
EXECUTE FUNCTION enforce_head_trainer_limit();

CREATE OR REPLACE FUNCTION check_schedule_overlap()
RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM FitnessCenterActivitySchedules
        WHERE FitnessCenterId = NEW.FitnessCenterId
          AND (
              (NEW.StartTime BETWEEN StartTime AND EndTime) OR
              (NEW.EndTime BETWEEN StartTime AND EndTime) OR
              (NEW.StartTime < StartTime AND NEW.EndTime > EndTime)
          )
    ) THEN
        RAISE EXCEPTION 'Schedule overlap detected in activity schedules for FitnessCenterId = %', 
                        NEW.FitnessCenterId;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM FitnessCenterSportEvents
        WHERE FitnessCenterId = NEW.FitnessCenterId
          AND (
              (NEW.StartTime BETWEEN StartTime AND EndTime) OR
              (NEW.EndTime BETWEEN StartTime AND EndTime) OR
              (NEW.StartTime < StartTime AND NEW.EndTime > EndTime)
          )
    ) THEN
        RAISE EXCEPTION 'Schedule overlap detected in sport events for FitnessCenterId = %', 
                        NEW.FitnessCenterId;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER prevent_activity_schedule_overlap
BEFORE INSERT OR UPDATE ON FitnessCenterActivitySchedules
FOR EACH ROW
EXECUTE FUNCTION check_schedule_overlap();

CREATE TRIGGER prevent_event_schedule_overlap
BEFORE INSERT OR UPDATE ON FitnessCenterSportEvents
FOR EACH ROW
EXECUTE FUNCTION check_schedule_overlap();

CREATE OR REPLACE FUNCTION check_activity_trainer_fitness_center()
RETURNS TRIGGER AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM Trainers t
        JOIN FitnessCenterActivities fca
        ON fca.FitnessCenterId = t.FitnessCenterId
        WHERE t.TrainerId = NEW.TrainerId
          AND fca.FitnessCenterId = NEW.FitnessCenterId
		  AND fca.ActivityId = NEW.ActivityId
    ) THEN
        RAISE EXCEPTION 'Trainer % does not belong to Fitness Center % for Activity %', NEW.TrainerId, NEW.FitnessCenterId, NEW.ActivityId;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER validate_activity_trainer_fitness_center
BEFORE INSERT OR UPDATE ON FitnessCenterActivityTrainers
FOR EACH ROW
EXECUTE FUNCTION check_activity_trainer_fitness_center();
