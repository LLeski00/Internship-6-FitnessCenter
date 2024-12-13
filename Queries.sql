SELECT t.FirstName, t.LastName, t.Gender, c.Name, c.AverageSalary FROM Trainers t
JOIN Countries c ON c.CountryId = t.CountryId;

SELECT fse.SportEventId, fse.StartTime, fse.EndTime, STRING_AGG(CONCAT_WS(', ', t.LastName, LEFT(t.FirstName, 1)), '; ') AS HeadTrainers
FROM FitnessCenterSportEvents fse
JOIN FitnessCenterSportEventTrainers fset ON fse.SportEventId = fset.SportEventId
                                          AND fse.FitnessCenterId = fset.FitnessCenterId
JOIN Trainers t ON fset.TrainerId = t.TrainerId
WHERE fset.TrainerType = 'Head trainer'
GROUP BY fse.SportEventId, fse.StartTime, fse.EndTime
ORDER BY fse.SportEventId, fse.StartTime;

SELECT fc.FitnessCenterId, fc.Name, COUNT(*) AS NumberOfActivities 
FROM FitnessCenters fc 
JOIN FitnessCenterActivitySchedules fcas ON fcas.FitnessCenterId = fc.FitnessCenterId
GROUP BY fc.FitnessCenterId
ORDER BY NumberOfActivities DESC
LIMIT 3;

SELECT t.trainerid, t.firstname, t.lastname, COUNT(fcat.activityid) AS NumberOfActivities,
CASE 
	WHEN COUNT(fcat.activityid) = 0 THEN 'Available'
	WHEN COUNT(fcat.activityid) <= 3 THEN 'Active'
	ELSE 'Completely occupied'
END AS Availability
FROM Trainers t
LEFT JOIN FitnessCenterActivityTrainers fcat ON t.trainerid = fcat.trainerid
GROUP BY t.trainerid;

SELECT DISTINCT p.ParticipantId, p.FirstName, p.LastName
FROM Participants p
JOIN FitnessCenterActivityParticipants fcap ON fcap.ParticipantId = p.ParticipantId;

SELECT DISTINCT t.TrainerId, t.FirstName, t.LastName
FROM Trainers t
JOIN FitnessCenterActivityTrainers fcat ON t.TrainerId = fcat.TrainerId
JOIN FitnessCenterActivitySchedules fcas ON fcat.FitnessCenterId = fcas.FitnessCenterId
                                         AND fcat.ActivityId = fcas.ActivityId
WHERE fcat.TrainerType = 'Head trainer' AND fcas.StartTime BETWEEN '2019-01-01' AND '2022-12-31';

SELECT c.Name AS CountryName, a.Type AS ActivityType, ROUND(AVG(NumberOfParticipants), 2) AS AvgParticipants
FROM Countries c
JOIN FitnessCenters fc ON c.CountryId = fc.CountryId
JOIN FitnessCenterActivities fca ON fc.FitnessCenterId = fca.FitnessCenterId
JOIN Activities a ON fca.ActivityId = a.ActivityId
LEFT JOIN (
    SELECT FitnessCenterId, ActivityId, COUNT(ParticipantId) AS NumberOfParticipants
    FROM FitnessCenterActivityParticipants
    GROUP BY FitnessCenterId, ActivityId
) AS participant_counts ON fca.FitnessCenterId = participant_counts.FitnessCenterId 
                        AND fca.ActivityId = participant_counts.ActivityId
GROUP BY c.CountryId, a.Type
ORDER BY c.CountryId, a.Type;

SELECT c.Name AS CountryName, COUNT(fcap.ParticipantId) AS NumberOfParticipants
FROM FitnessCenterActivityParticipants fcap
JOIN FitnessCenterActivities fca ON fcap.FitnessCenterId = fca.FitnessCenterId
                                 AND fcap.ActivityId = fca.ActivityId
JOIN Activities a ON fca.ActivityId = a.ActivityId
JOIN Participants p ON fcap.ParticipantId = p.ParticipantId
JOIN Countries c ON p.CountryId = c.CountryId
WHERE a.Type = 'Injury rehabilitation'
GROUP BY c.Name
ORDER BY NumberOfParticipants DESC
LIMIT 10;

SELECT fca.FitnessCenterId, fca.ActivityId, a.Name AS ActivityName,
    CASE 
        WHEN COUNT(fcap.ParticipantId) < fca.MaxParticipants THEN 'AVAILABLE'
        ELSE 'FULL'
    END AS Status
FROM FitnessCenterActivities fca
LEFT JOIN FitnessCenterActivityParticipants fcap ON fca.FitnessCenterId = fcap.FitnessCenterId
                                                 AND fca.ActivityId = fcap.ActivityId
JOIN Activities a ON fca.ActivityId = a.ActivityId
GROUP BY fca.FitnessCenterId, fca.ActivityId, a.Name
ORDER BY Status DESC;

SELECT t.TrainerId, t.FirstName, t.LastName, SUM(COALESCE(fcap.NumberOfParticipants, 0) * fca.PricePerSession) AS TotalEarnings
FROM Trainers t
JOIN FitnessCenterActivityTrainers fcat ON fcat.TrainerId = t.TrainerId
JOIN FitnessCenterActivities fca ON fca.FitnessCenterId = fcat.FitnessCenterId 
                                 AND fca.ActivityId = fcat.ActivityId
LEFT JOIN (
	SELECT 
		FitnessCenterId,
		ActivityId,
		COUNT(ParticipantId) AS NumberOfParticipants
	FROM 
		FitnessCenterActivityParticipants
	GROUP BY 
		FitnessCenterId, ActivityId
    ) fcap ON fca.FitnessCenterId = fcap.FitnessCenterId 
           AND fca.ActivityId = fcap.ActivityId
GROUP BY t.TrainerId, t.FirstName, t.LastName
ORDER BY TotalEarnings DESC
LIMIT 10;

