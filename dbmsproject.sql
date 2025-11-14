DROP DATABASE IF EXISTS musicdb;
CREATE DATABASE musicdb;
USE musicdb;

CREATE TABLE Singer (
    Singer_id INT AUTO_INCREMENT PRIMARY KEY,
    First_name VARCHAR(50) NOT NULL,
    Middle_name VARCHAR(50),
    Last_name VARCHAR(50) NOT NULL
);

CREATE TABLE Album (
    Album_id INT AUTO_INCREMENT PRIMARY KEY,
    Album_name VARCHAR(150) NOT NULL
);

CREATE TABLE Genre (
    Genre_id INT AUTO_INCREMENT PRIMARY KEY,
    Genre_name VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE Track (
    Track_id INT AUTO_INCREMENT PRIMARY KEY,
    Track_name VARCHAR(200) NOT NULL,
    Lyrics TEXT,
    Album_id INT NOT NULL,
    Genre_id INT NOT NULL,
    CONSTRAINT fk_track_album FOREIGN KEY (Album_id)
        REFERENCES Album(Album_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_track_genre FOREIGN KEY (Genre_id)
        REFERENCES Genre(Genre_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

CREATE TABLE Sings_in (
    Singer_id INT NOT NULL,
    Album_id INT NOT NULL,
    PRIMARY KEY (Singer_id, Album_id),
    CONSTRAINT fk_singsin_singer FOREIGN KEY (Singer_id)
        REFERENCES Singer(Singer_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_singsin_album FOREIGN KEY (Album_id)
        REFERENCES Album(Album_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE TABLE Sung_by (
    Track_id INT NOT NULL,
    Singer_id INT NOT NULL,
    PRIMARY KEY (Track_id, Singer_id),
    CONSTRAINT fk_sungby_track FOREIGN KEY (Track_id)
        REFERENCES Track(Track_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_sungby_singer FOREIGN KEY (Singer_id)
        REFERENCES Singer(Singer_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

INSERT INTO Genre (Genre_name) VALUES
('Pop'),
('Rock'),
('Jazz'),
('Classical');

INSERT INTO Album (Album_name) VALUES
('Sunrise Hits'),
('Electric Dreams'),
('Acoustic Sessions');

INSERT INTO Singer (First_name, Middle_name, Last_name) VALUES
('Asha', NULL, 'Sharma'),
('Ravi', 'K.', 'Kumar'),
('Lina', NULL, 'Torres');

INSERT INTO Track (Track_name, Lyrics, Album_id, Genre_id) VALUES
('Morning Light', 'La la la ...', 1, 1),
('Electric Heart', 'Oh baby ...', 2, 2),
('Soft Strings', 'hum hum ...', 3, 3);

INSERT INTO Sings_in (Singer_id, Album_id) VALUES
(1, 1),
(2, 2),
(3, 3);

INSERT INTO Sung_by (Track_id, Singer_id) VALUES
(1, 1),
(2, 2),
(3, 3);

SELECT 
    t.Track_id,
    t.Track_name,
    a.Album_name,
    g.Genre_name,
    CONCAT(s.First_name, ' ', IFNULL(CONCAT(s.Middle_name, ' '), ''), s.Last_name) AS Singer_name
FROM Track t
JOIN Album a ON t.Album_id = a.Album_id
JOIN Genre g ON t.Genre_id = g.Genre_id
LEFT JOIN Sung_by sb ON t.Track_id = sb.Track_id
LEFT JOIN Singer s ON sb.Singer_id = s.Singer_id
ORDER BY t.Track_id;

INSERT INTO Singer (First_name, Middle_name, Last_name)
VALUES ('Maya', 'R.', 'Shah');

UPDATE Genre SET Genre_name = 'Contemporary Pop' WHERE Genre_id = 1;

DELETE FROM Singer WHERE Singer_id = 4;

SELECT * FROM Singer;
SELECT * FROM Album;
SELECT * FROM Genre;
SELECT * FROM Track;
SELECT * FROM Sings_in;
SELECT * FROM Sung_by;

CREATE TABLE Singer_Audit (
    Audit_id INT AUTO_INCREMENT PRIMARY KEY,
    Singer_id INT NOT NULL,
    Old_First_name VARCHAR(50),
    New_First_name VARCHAR(50),
    Old_Last_name VARCHAR(50),
    New_Last_name VARCHAR(50),
    Change_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (Singer_id) REFERENCES Singer(Singer_id) ON DELETE CASCADE
);
DELIMITER $$

CREATE TRIGGER trg_Singer_Name_Update
BEFORE UPDATE ON Singer
FOR EACH ROW
BEGIN
    -- Check if the first name or last name is being changed
    IF OLD.First_name <> NEW.First_name OR OLD.Last_name <> NEW.Last_name THEN
        INSERT INTO Singer_Audit (
            Singer_id, 
            Old_First_name, 
            New_First_name, 
            Old_Last_name, 
            New_Last_name
        )
        VALUES (
            OLD.Singer_id, 
            OLD.First_name, 
            NEW.First_name, 
            OLD.Last_name, 
            NEW.Last_name
        );
    END IF;
END$$

DELIMITER ;
-- Update a singer's name
UPDATE Singer SET First_name = 'Asha-ji' WHERE Singer_id = 1;

-- Check the audit log
SELECT * FROM Singer_Audit;
DELIMITER $$

CREATE TRIGGER trg_Auto_Link_Singer_To_Album
AFTER INSERT ON Sung_by
FOR EACH ROW
BEGIN
    DECLARE v_Album_id INT;

    -- 1. Find the Album_id for the new track
    SELECT Album_id INTO v_Album_id 
    FROM Track 
    WHERE Track_id = NEW.Track_id;

    -- 2. Add the singer to the 'Sings_in' table for that album
    -- 'INSERT IGNORE' will safely do nothing if the link already exists
    -- (preventing a primary key violation error)
    INSERT IGNORE INTO Sings_in (Singer_id, Album_id)
    VALUES (NEW.Singer_id, v_Album_id);
END$$

DELIMITER ;
-- Assuming Track_id 2 ('Electric Heart') is on Album_id 2 ('Electric Dreams')
-- And Singer_id 1 ('Asha Sharma') is NOT linked to Album_id 2
-- This INSERT will link Asha to the track...
INSERT INTO Sung_by (Track_id, Singer_id) VALUES (2, 1);

-- ...and the trigger will automatically run this:
-- INSERT IGNORE INTO Sings_in (Singer_id, Album_id) VALUES (1, 2);

-- Check the result:
SELECT * FROM Sings_in WHERE Singer_id = 1 AND Album_id = 2;
DELIMITER $$

CREATE PROCEDURE sp_SearchTracksBySinger(
    IN p_SingerName VARCHAR(100)
)
BEGIN
    SET p_SingerName = CONCAT('%', p_SingerName, '%');

    SELECT 
        t.Track_name,
        a.Album_name,
        g.Genre_name,
        CONCAT(s.First_name, ' ', IFNULL(CONCAT(s.Middle_name, ' '), ''), s.Last_name) AS Singer_name
    FROM Track t
    JOIN Album a ON t.Album_id = a.Album_id
    JOIN Genre g ON t.Genre_id = g.Genre_id
    JOIN Sung_by sb ON t.Track_id = sb.Track_id
    JOIN Singer s ON sb.Singer_id = s.Singer_id
    WHERE 
        s.First_name LIKE p_SingerName 
        OR s.Last_name LIKE p_SingerName 
        OR CONCAT(s.First_name, ' ', s.Last_name) LIKE p_SingerName
    ORDER BY Singer_name, a.Album_name, t.Track_name;
END$$

DELIMITER ;
CALL sp_SearchTracksBySinger('Ravi');
CALL sp_SearchTracksBySinger('Torres');
DELIMITER $$

CREATE PROCEDURE sp_AddNewTrackAndLinkSinger(
    IN p_TrackName VARCHAR(200),
    IN p_Lyrics TEXT,
    IN p_AlbumID INT,
    IN p_GenreID INT,
    IN p_SingerID INT
)
BEGIN
    DECLARE v_NewTrackID INT;

    -- Start a transaction
    START TRANSACTION;

    -- 1. Insert the new track
    INSERT INTO Track (Track_name, Lyrics, Album_id, Genre_id)
    VALUES (p_TrackName, p_Lyrics, p_AlbumID, p_GenreID);
    
    -- 2. Get the new Track_id that was just created
    SET v_NewTrackID = LAST_INSERT_ID();

    -- 3. Link the singer to this new track
    INSERT INTO Sung_by (Track_id, Singer_id)
    VALUES (v_NewTrackID, p_SingerID);
    
    -- (Note: The trg_Auto_Link_Singer_To_Album will fire here automatically)

    -- Commit the transaction
    COMMIT;

    -- Return the new track info as confirmation
    SELECT * FROM Track WHERE Track_id = v_NewTrackID;
END$$

DELIMITER ;
-- Add a new track 'Quiet Night' for 'Lina Torres' (Singer_id 3)
-- to 'Acoustic Sessions' (Album_id 3) as 'Jazz' (Genre_id 3)
CALL sp_AddNewTrackAndLinkSinger(
    'Quiet Night', 
    '...', 
    3, 
    3, 
    3
);
DELIMITER $$

CREATE FUNCTION fn_GetSingerFullName(
    p_SingerID INT
)
RETURNS VARCHAR(152) -- 50 + 50 + 50 + 2 spaces
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_FullName VARCHAR(152);

    SELECT 
        CONCAT(First_name, ' ', IFNULL(CONCAT(Middle_name, ' '), ''), Last_name)
    INTO v_FullName
    FROM Singer
    WHERE Singer_id = p_SingerID;

    RETURN v_FullName;
END$$

DELIMITER ;
-- Use it directly in a SELECT statement
SELECT 
    Album_name, 
    fn_GetSingerFullName(s.Singer_id) AS Singer_Name
FROM Album a
JOIN Sings_in s ON a.Album_id = s.Album_id
WHERE a.Album_id = 2;
DELIMITER $$

CREATE FUNCTION fn_GetAlbumTrackCount(
    p_AlbumID INT
)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_TrackCount INT;

    SELECT COUNT(*)
    INTO v_TrackCount
    FROM Track
    WHERE Album_id = p_AlbumID;

    RETURN v_TrackCount;
END$$

DELIMITER ;
-- Get a report of all albums and their track counts
SELECT 
    Album_id,
    Album_name,
    fn_GetAlbumTrackCount(Album_id) AS Total_Tracks
FROM Album
ORDER BY Total_Tracks DESC;