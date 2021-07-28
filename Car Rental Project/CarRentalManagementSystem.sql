CREATE database car_rental;

USE car_rental_management;
CREATE TABLE RENTAL_LOCATION
(
  Rental_Location_ID INT PRIMARY KEY,  
  Phone CHAR(10) NOT NULL,
  Email VARCHAR(25),
  Street_Name VARCHAR(40) NOT NULL,
  State CHAR(2) NOT NULL,
  Zip_Code CHAR(6) NOT NULL
);

CREATE TABLE CAR_TYPE
(
  Car_Type VARCHAR(15) PRIMARY KEY,
  Price_Per_Day  INT NOT NULL  
);

CREATE TABLE INSURANCE
(
  Insurance_Type VARCHAR(15) PRIMARY KEY,
  Bodily_Coverage  INT NOT NULL,
  Medical_Coverage  INT NOT NULL,
  Collision_Coverage  INT NOT NULL
);

CREATE TABLE CAR_INSURANCE
(
  Car_Type VARCHAR(15),
  Insurance_Type VARCHAR(15),
  Insurance_Price  INT NOT NULL,
  PRIMARY KEY(Car_Type,Insurance_Type),
  CONSTRAINT CARTYPEFK
  FOREIGN KEY (Car_Type) REFERENCES CAR_TYPE(Car_Type)
              ON DELETE CASCADE,
  CONSTRAINT INSURANCETYPEFK
  FOREIGN KEY (Insurance_Type) REFERENCES INSURANCE(Insurance_Type)
              ON DELETE CASCADE            
);

CREATE TABLE CAR_USER
(
  License_No VARCHAR(15) PRIMARY KEY,
  Fname VARCHAR(15) NOT NULL,
  Mname VARCHAR(1),
  Lname VARCHAR(15) NOT NULL,
  Email VARCHAR(25) NOT NULL UNIQUE,
  Address VARCHAR(100) NOT NULL,
  Phone CHAR(10) NOT NULL,
  DOB DATE NOT NULL,
  User_Type VARCHAR(10) NOT NULL
);

CREATE TABLE USER_CREDENTIALS
(
  Login_ID VARCHAR(15) PRIMARY KEY,
  Password VARCHAR(15) NOT NULL,
  Year_Of_Membership Char(4) NOT NULL ,
  License_No VARCHAR(15) NOT NULL,
  CONSTRAINT USRLIC
  FOREIGN KEY (License_No) REFERENCES CAR_USER(License_No)
              ON DELETE CASCADE
);

CREATE TABLE CARD_DETAILS
(
  Login_ID VARCHAR(15) NOT NULL,
  Name_On_Card VARCHAR(50) NOT NULL,
  Card_No CHAR(16) NOT NULL,
  Expiry_Date DATE NOT NULL,
  CVV CHAR(3) NOT NULL,
  Billing_Address VARCHAR(50) NOT NULL,
  PRIMARY KEY(Login_ID,Card_No),
  CONSTRAINT USRCARDFK
  FOREIGN KEY (Login_ID) REFERENCES USER_CREDENTIALS(Login_ID)
              ON DELETE CASCADE
);

CREATE TABLE CAR
(
  VIN CHAR(17) PRIMARY KEY,
  Rental_Location_ID INT NOT NULL,
  Reg_No VARCHAR(15) UNIQUE,
  Status VARCHAR(15) NOT NULL,
  Seating_Capacity INT NOT NULL,
  Disability_Friendly CHAR(1),
  Car_Type VARCHAR(15) NOT NULL, 
  Model VARCHAR(20),
  Year CHAR(4),
  Color VARCHAR(10),
  CONSTRAINT CARVINTYPEFK
  FOREIGN KEY (Car_Type) REFERENCES CAR_TYPE(Car_Type)
              ON DELETE CASCADE,
  CONSTRAINT CARVINRENTALFK
  FOREIGN KEY (Rental_Location_ID) REFERENCES RENTAL_LOCATION(Rental_Location_ID)
              ON DELETE CASCADE         
);

CREATE TABLE OFFER_DETAILS
(
  Promo_Code VARCHAR(15) PRIMARY KEY,
  Description VARCHAR(50),
  Promo_Type VARCHAR(20) NOT NULL,
  Is_One_Time CHAR(1),
  Percentage DECIMAL(5,2),
  Discounted_Amount  INT,
  Status VARCHAR(10) NOT NULL
);

CREATE TABLE RESERVATION
(
  Reservation_ID INT PRIMARY KEY,
  Start_Date DATE NOT NULL,
  End_Date DATE NOT NULL,
  Meter_Start INT NOT NULL,
  Meter_End INT,
  Rental_Amount INT NOT NULL,
  Insurance_Amount  INT NOT NULL,
  Actual_End_Date DATE NULL,
  Status VARCHAR(10) NOT NULL,
  License_No VARCHAR(15) NOT NULL,
  VIN CHAR(17) NOT NULL,
  Promo_Code VARCHAR(15),
  Additional_Amount  INT,
  Tot_Amount  INT NOT NULL,
  Insurance_Type VARCHAR(15),
  Penalty_Amount  INT,
  Drop_Location_ID INT,  
  CONSTRAINT RSERVLOCATIONFK
  FOREIGN KEY (Drop_Location_ID) REFERENCES RENTAL_LOCATION(Rental_Location_ID)
              ON DELETE CASCADE,
  CONSTRAINT RESLICENSEFK
  FOREIGN KEY (License_No) REFERENCES CAR_USER(License_No)
              ON DELETE CASCADE,
  /*CONSTRAINT VINRESERVATIONFK
  FOREIGN KEY (VIN) REFERENCES CAR(VIN)
              ON DELETE CASCADE,*/
  CONSTRAINT PROMORESERVATIONFK
  FOREIGN KEY (Promo_Code) REFERENCES OFFER_DETAILS(Promo_Code)
              ON DELETE CASCADE,
  CONSTRAINT INSURESERVATIONFK
  FOREIGN KEY (Insurance_Type) REFERENCES INSURANCE(Insurance_Type)
              ON DELETE CASCADE
);

CREATE TABLE PAYMENT
(
  Payment_ID INT PRIMARY KEY,
  Amount_Paid INT NOT NULL,
  Card_No CHAR(16),
  Expiry_Date DATE,
  Name_On_Card VARCHAR(50),
  CVV CHAR(3),
  Billing_Address VARCHAR(50),
  Reservation_ID INT NOT NULL,
  Login_ID VARCHAR(15),
  Saved_Card_No CHAR(16),
  Paid_By_Cash CHAR(1),
  CONSTRAINT PAYMENTRESERVATIONFK
  FOREIGN KEY (Reservation_ID) REFERENCES RESERVATION(Reservation_ID)
              ON DELETE CASCADE,
  CONSTRAINT PAYMENTLOGINFK
  FOREIGN KEY (Login_ID,Saved_Card_No) REFERENCES CARD_DETAILS(Login_ID,Card_No)
              ON DELETE CASCADE
);
commit;

delimiter |
CREATE TRIGGER date_check before insert on reservation
FOR EACH ROW
	BEGIN
		if(DATEDIFF(new.Actual_End_Date,new.End_date)>=0) then
			set new.Penalty_Amount=(DATEDIFF(new.Actual_End_Date,new.End_date)*50);
		END IF;
	END |
delimiter ;
DROP TRIGGER date_check;


delimiter |
CREATE TRIGGER rent_amt before insert on reservation
FOR EACH ROW
	BEGIN 
		SET @carType=(select C.Car_Type from car as C where new.VIN=C.VIN);
        SET @price=(select Price_Per_Day from car_type where Car_Type=@carType);
        set new.Rental_Amount=@price*(DATEDIFF(new.Actual_End_Date,new.Start_Date));
	END |
delimiter ;
DROP TRIGGER rent_amt;


delimiter |
CREATE TRIGGER ins_amt before insert on reservation
FOR EACH ROW
	BEGIN
		SET @carType=(select C.Car_Type from car as C where new.VIN=C.VIN);
        SET @price=(select C.Insurance_Price from car_insurance as C
         where C.Car_Type=@carType and C.Insurance_Type=new.Insurance_Type);
		set new.Insurance_Amount=@price*(DATEDIFF(new.Actual_End_Date,new.Start_Date));
	END |
delimiter ;
DROP TRIGGER ins_amt;


delimiter |
CREATE trigger Tot_Amount before insert on reservation
FOR EACH ROW 
	BEGIN 
		DECLARE v1,v2 INT;
		select offer.Percentage,offer.Discounted_Amount into v1,v2 from offer_details as offer where new.Promo_Code=offer.Promo_Code;
        SET @availability=(select offer.STATUS from offer_details as offer where new.Promo_Code=offer.Promo_Code);
        SET @isOneTime=(select offer.Is_One_Time from offer_details as offer where new.Promo_Code=offer.Promo_Code);
        if @isOneTime='Y' then
			update offer_details SET Status='Expired'
            WHERE Promo_Code=new.Promo_Code;
			END IF;
        if v1 is not null then
			if @availability='Available' then
				set new.Tot_Amount=(new.Rental_Amount+new.Insurance_Amount+new.Penalty_Amount)-
				((v1/100)*(new.Rental_Amount+new.Insurance_Amount+new.Penalty_Amount));
			else
				set new.Tot_Amount=(new.Rental_Amount+new.Insurance_Amount+new.Penalty_Amount);
			END IF;
            
		else 
			if @availability='Available' then
				set new.Tot_Amount=(new.Rental_Amount+new.Insurance_Amount+new.Penalty_Amount)-v2;
			else
				set new.Tot_Amount=(new.Rental_Amount+new.Insurance_Amount+new.Penalty_Amount);
			END IF;
		END IF;
	END |;
delimiter ;
DROP TRIGGER Tot_Amount;


DELIMITER |
CREATE TRIGGER check_amount before insert on payment
FOR EACH ROW
	BEGIN
		SET @amount=(select R.Tot_Amount from reservation as R where new.Reservation_ID=R.Reservation_ID);
		IF new.Amount_Paid>@amount then
			SET new.Amount_Paid=@amount;
		END IF;
	END |;
delimiter ;
DROP TRIGGER check_amount;

-- Queries
-- 1)Find the names of the car users who have not paid the full amount

	select C.Fname,C.Lname
	from car_user as C 
	where C.License_No not in (select R.License_No
					           from reservation as R
					           where R.Reservation_ID=(select P.Reservation_ID 
													   from payment as P
                                                       where P.Amount_Paid=R.Tot_Amount));


-- This is Reservation_ID of all car_users with their amount paid

select R.Reservation_ID,R.Tot_Amount,P.Amount_Paid
from reservation R,payment P
where R.Reservation_ID=P.Reservation_ID;


-- 2) Find the telephone numbers for the cars stored in rental locations used in our database
select r.Phone
from rental_location r
where exists( select c.Rental_Location_ID 
                  from car c
                  where c.Rental_Location_ID=r.Rental_Location_ID);
                  
                  
-- The telephone numbers of all the rental locations used in our database
select Rental_Location_ID,Phone
from rental_location;


-- 3)Find the car models used in our database
select C.Model
from car as C
where EXISTS(select R.VIN
			 from reservation as R
             where R.VIN=C.VIN);
              
              
-- This is all the car models present in our database              
select Model
from car;

              
-- 4)Find the type of the car and price for it used in our database when price of the car type is greater than 85              
select DISTINCT CT.Car_Type,CT.Price_Per_Day
from car_type as CT,reservation as R,car as C
where R.VIN=C.VIN and C.Car_Type=CT.Car_Type and CT.Price_Per_Day>85;


select *
from car_type;


-- 5) Find the reservation id and the Total Amount for the maximum Total_Amount in our database
SELECT Reservation_ID,MAX(Tot_Amount)
FROM reservation;

select Reservation_ID,Tot_Amount
from reservation;

-- 6)Find the left join of car_insurance with insurance
select *
from car_insurance  C  left join insurance  I
ON C.Insurance_Type=I.Insurance_Type;

select *
from car_insurance;

select *
from insurance;

-- Insert statements

INSERT INTO RENTAL_LOCATION
(Rental_Location_ID,Phone,Email,Street_Name,State,Zip_Code) 
VALUES 
(101,'9726031111','adams12@gmail.com','980 Addison Road, Dallas','TX',75123),

(102,'9726032222','bobw@gmail.com',' 111, Berlington Road, Dallas','TX',75243),

(103,'9721903121','patric.clever@gmail.com',' 9855 Shadow Way, Dallas','TX',75211),

(104,'721903121',NULL,'434 Harrodswood Road, Irving','TX',76512),

(105,'5026981045','julier@gmail.com','7788 internal Drive, Irving','TX',77888);


INSERT 
INTO CAR_TYPE 
(Car_Type,Price_Per_Day) 
VALUES 
('Economy',19.95),
 
('Standard',29.95),

('SUV',89.95),
 
('MiniVan',109.95),

('Premium',149.95);


INSERT 
INTO INSURANCE
(Insurance_Type,Bodily_Coverage,Medical_Coverage,Collision_Coverage) 
VALUES 
('Liability',25000.00,50000.00,0.00),
 

('Comprehensive',50000.00,50000.00,50000.00);


INSERT 
INTO CAR_INSURANCE
(Car_Type,Insurance_Type,Insurance_Price)
VALUES
('Economy','Liability',9.99),
 

('Standard','Liability',10.99),
 

('SUV','Liability',12.99),
 

('MiniVan','Liability',14.99),
 

('Premium','Liability',19.99),

('Economy','Comprehensive',19.99),
 

('Standard','Comprehensive',19.99),
 

('SUV','Comprehensive',24.99),
 

('MiniVan','Comprehensive',29.99),
 

('Premium','Comprehensive',49.99);


INSERT INTO CAR_USER
(License_No,FName,MName,Lname,Email,Address,Phone,DOB,USER_TYPE)
VALUES
('E12905109','Patrick','G','Cleaver','patric.c@yahoo.com','1701 N.Campbell Rd, Dallas, TX-75243','5022196058',('1970-01-10'),'Guest'),
 

('C11609103','Courtney',NULL,'Rollins','courtney.r@hotmail.com','1530 S.Campbell Rd','4697891045',('1990-03-20'),'Customer'),
 

('G30921561','Glenn',NULL,'Tucker','glenn.t@hotmail.com','101 Meritline drive','8590125607',('1964-11-11'),'Customer'),
 

('R12098127','Ron',NULL,'Harper','ron.harper@hotmail.com','43 Greenville Road','2048015647',('1987-04-24'),'Guest'),
 

('M12098127','Manoj',NULL,'Punwani','manoj123@gmail.com','43 Greenville Road','2048015647',('1987-04-24'),'Customer');



INSERT INTO USER_CREDENTIALS
(Login_ID,Password,Year_Of_Membership,License_No)
VALUES
('courtney90','bc125ac','2009','C11609103'),
 

('glenn64','macpro99','2011','G30921561'),
 

('manoj87','windows99','2008','M12098127');



INSERT INTO CARD_DETAILS
(Login_ID,Name_On_Card,Card_No,Expiry_Date,CVV,Billing_Address)
VALUES
('courtney90','Courtney Rollins','4735111122223333',('2018-01-15'),'833','1530 S.Campbell Rd, Dallas, TX 75251'),
 

('manoj87','Manoj Punwani','4233908110921001',('2019-12-31'),'419','9855 Shadow Way, TX 75243');



INSERT INTO CAR
(VIN,Rental_Location_ID,Reg_No,Status,Seating_Capacity,Disability_Friendly,Car_Type,Model,Year,Color)
VALUES
('F152206785240289',101,'TXF101','Available',5,'N','Economy','Mazda3','2007','Gold'),
 

('T201534710589051',101,'KYQ101','Available',5,'Y','Standard','Toyota Camry','2012','Grey'),
 

('E902103289341098',102,'XYZ671','Available',5,NULL,'Premium','BMW','2015','Black'),
 

('R908891209418173',103,'DOP391','Unavailable',7,NULL,'SUV','Acura MDX','2014','White'),

('N892993994858292',104,'RAC829','Available',15,NULL,'MiniVan','Sienna','2013','Black');



INSERT INTO OFFER_DETAILS
(PROMO_CODE,DESCRIPTION,PROMO_TYPE,IS_ONE_TIME,PERCENTAGE,DISCOUNTED_AMOUNT,Status)
VALUES
('CHRISTMAS10','Christmas 10% offer','Percentage','N',10.00,NULL,'Available'),

('July25','July $25.00 discount','Discounted Amount','Y',NULL,25.00,'Expired'),

('LaborDay5','Labor Day $5.00 offer','Discounted Amount','Y',NULL,5.00,'Expired'),

('NewYear10','New Year 10% offer','Percentage','N',10.00,NULL,'Available'),

('VeteranDay15','New Year 15% offer','Percentage','N',15.00,NULL,'Expired');



INSERT INTO RESERVATION
(Reservation_ID,Start_Date,End_Date,Meter_Start,Meter_End,Rental_Amount,Insurance_Amount,Status,Actual_End_Date,License_No,VIN,Promo_Code,Additional_Amount,Tot_Amount,Penalty_Amount,Insurance_Type,Drop_Location_ID)
VALUES

(1,('2015-11-06'),('2015-11-12'),81256,81300,119.70,9.95,'Completed',('2015-11-12'),'E12905109','F152206785240289',NULL,NULL,129.65,0.00,'Liability',101),

(2,('2015-10-20'),('2015-10-24'),76524,76590,119.80,9.95,'Completed',('2015-10-24'),'C11609103','T201534710589051',NULL,NULL,129.75,0.00,'Liability',101),

(3,('2015-12-06'),('2015-12-12'),82001,NULL,659.40,29.95,'Reserved',NULL,'C11609103','N892993994858292','NewYear10',NULL,689.35,0.00,'Comprehensive',104),

(4,('2015-09-01'),('2015-09-02'),51000,51100,89.95,24.95,'Completed',('2015-09-02'),'C11609103','R908891209418173',NULL,NULL,114.90,0.00,'Comprehensive',103),

(5,('2015-08-13'),('2015-08-15'),51000,51100,299.00,99.9,'Completed',('2015-08-15'),'R12098127','E902103289341098',NULL,NULL,398.90,0.00,'Comprehensive',105);



INSERT INTO PAYMENT
(Payment_ID,Amount_Paid,Card_NO,Expiry_Date,Name_On_Card,CVV,Billing_Address,Reservation_ID,Login_ID,Saved_Card_No,Paid_By_Cash)
VALUES
(1001,129.65,'4735111122223333',('2018-01-15'),'Patric Clever','100','1530 S.Campbell Rd, Dallas, TX 75251',1,NULL,NULL,NULL),

(1002,300.00,NULL,NULL,NULL,NULL,NULL,5,NULL,NULL,'Y'),

(1003,98.90,NULL,NULL,NULL,NULL,NULL,5,NULL,NULL,'Y'),

(1004,689.35,NULL,NULL,NULL,NULL,NULL,3,'courtney90','4735111122223333',NULL),

(1005,114.91,NULL,NULL,NULL,NULL,NULL,4,NULL,NULL,'Y');



INSERT INTO ADDITIONAL_DRIVER
(Reservation_ID,Name,DOB)
VALUES
(1,'William Smith',('1970-07-15')),

(2,'Green Taylor',('1987-06-15')),

(2,'Robert Moore',('1990-12-17')),

(4,'Brad Cook',('1966-12-12')),

(5,'Steve Fouts',('1976-05-28'));



INSERT INTO ACCESSORIES
(Accessory_ID,Type,Quantity,Amount)
VALUES
(1,'GPS Navigation',2,49.95),

(2,'GPS Navigation',1,49.95),

(3,'GPS Navigation',2,49.95),

(4,'Baby Seater',2,29.95),

(5,'Baby Seater',3,29.95);



INSERT INTO ACCESSORY_RESERVED
(Accessory_ID,Reservation_ID)
VALUES
(1,1),

(1,4),

(5,5),

(5,2),

(2,4);

commit;
/*

-------------------------------------------------
-- PL/SQL 
-------------------------------------------------
-- Update Reservation, Promo_Code and Car status with Drop Location ID
CREATE OR REPLACE PROCEDURE UpdateStatus AS
BEGIN
DECLARE
  thisReservation RESERVATION%ROWTYPE;
CURSOR reservationCursor IS
    SELECT R.* FROM RESERVATION R WHERE R.STATUS = 'Reserved' AND
    R.TOT_AMOUNT <= (SELECT SUM(AMOUNT_PAID) FROM PAYMENT P WHERE P.RESERVATION_ID = R.RESERVATION_ID)
    FOR UPDATE OF STATUS;
BEGIN 
  OPEN reservationCursor;
LOOP
  FETCH reservationCursor INTO thisReservation;
   EXIT WHEN (reservationCursor%NOTFOUND);
  -- Update Reservation Status
  UPDATE RESERVATION SET STATUS = 'Completed'
  WHERE CURRENT OF reservationCursor;
  -- Update Promo_Code Status
  UPDATE OFFER_DETAILS SET STATUS = 'Expired'
  WHERE PROMO_CODE = thisReservation.PROMO_CODE AND IS_ONE_TIME = 'Y';
  -- Update Rental_Location Of Car as Drop Location ID and Car Status
  UPDATE CAR SET RENTAL_LOCATION_ID = thisReservation.Drop_Location_ID,STATUS = 'Available'
  WHERE CAR.VIN = thisReservation.VIN;
END LOOP;
CLOSE reservationCursor;
END;
END UpdateStatus;

-- Call the procedure
SET SERVEROUTPUT ON
BEGIN
UpdateStatus;
END;

-- Increase the insurance price by given percentage
CREATE OR REPLACE PROCEDURE IncreaseInsuranceRate(percentage IN NUMBER) AS
BEGIN
DECLARE
  thisCarInsurance CAR_Insurance%ROWTYPE;
CURSOR carInsuranceCursor IS
    SELECT * FROM CAR_INSURANCE 
    FOR UPDATE OF Insurance_Price;
BEGIN 
  OPEN carInsuranceCursor;
LOOP
  FETCH carInsuranceCursor INTO thisCarInsurance;
   EXIT WHEN (carInsuranceCursor%NOTFOUND);
 
  UPDATE CAR_INSURANCE SET Insurance_Price = (Insurance_Price + (Insurance_Price*percentage/100))
  WHERE CURRENT OF carInsuranceCursor; 
END LOOP;
CLOSE carInsuranceCursor;
END;
END IncreaseInsuranceRate;

-- Print Reservations whose End Date is in the past and Car not yet returned
SET SERVEROUTPUT ON
DECLARE
  thisVIN CAR.VIN%TYPE;
  thisLicenseNo CAR_USER.License_No%TYPE;
  thisCarUser CAR_USER%ROWTYPE;
  CURSOR openReservationCursor IS
    SELECT VIN,License_No FROM RESERVATION WHERE STATUS = 'Reserved' AND END_DATE < SYSDATE AND ACTUAL_END_DATE IS NULL;
BEGIN
  OPEN openReservationCursor;
LOOP
  FETCH openReservationCursor INTO thisVIN,thisLicenseNo;
   EXIT WHEN (openReservationCursor%NOTFOUND);
  SELECT * INTO thisCarUser FROM CAR_USER WHERE License_No = thisLicenseNo;  
  dbms_output.put_line( 'User ' || thisCarUser.Fname || ' ' || thisCarUser.Mname || ' ' || thisCarUser.Lname || '  ' || 'whose email id is ' ||  thisCarUser.Email ||
  ' has not returned the car with VIN ' || thisVIN ||'.');
END LOOP;
  CLOSE openReservationCursor;
END;

-- Print Promo code which are NOT of type One Time and number of times it is used till now.
SET SERVEROUTPUT ON
DECLARE
  thispromoCode OFFER_DETAILS.Promo_Code%TYPE;
  thispromoCodeCount INT;
--  thisLicenseNo CAR_USER.License_No%TYPE;
--  thisCarUser CAR_USER%ROWTYPE;
  CURSOR openOfferDetailsCursor IS
    SELECT Promo_Code FROM OFFER_DETAILS WHERE Is_One_Time <> 'Y';
BEGIN
  OPEN openOfferDetailsCursor;
LOOP
  FETCH openOfferDetailsCursor INTO thispromoCode;
   EXIT WHEN (openOfferDetailsCursor%NOTFOUND);
  SELECT COUNT(*) INTO thispromoCodeCount FROM RESERVATION WHERE PROMO_CODE = thispromoCode;  
  dbms_output.put_line( 'Promo Code ' || thispromoCode || ' has been used ' || thispromoCodeCount || ' times.');
END LOOP;
  CLOSE openOfferDetailsCursor;
END;

-------------------------------------------------
-- End of Coding
-------------------------------------------------*/