-- set up snowflake environment and create required objects
CREATE OR REPLACE DATABASE CUSTOMER_EXP_DB;
CREATE OR REPLACE SCHEMA CUSTOMER_EXP_SCHEMA;
CREATE OR REPLACE WAREHOUSE VINO_CUSTOMER_EXP_WH_M WAREHOUSE_SIZE='MEDIUM';

USE DATABASE CUSTOMER_EXP_DB;
USE SCHEMA CUSTOMER_EXP_SCHEMA;
USE WAREHOUSE VINO_CUSTOMER_EXP_WH_M;

-- count the rows from the marketplace data
SELECT COUNT(*) as row_count 
FROM CUSTOMER_EXP.PUBLIC.TRIAL_PRODUCT_CUSTOMER_EXPERIENCE_VIEW;

-- peek into the customer_exp data from marketplace
SELECT * 
FROM CUSTOMER_EXP.PUBLIC.TRIAL_PRODUCT_CUSTOMER_EXPERIENCE_VIEW
LIMIT 5;

-- create a table to copy the data from the marketplace data
CREATE OR REPLACE TABLE CUSTOMER_EXP_REVIEWS (
    brand_name VARCHAR(100),
    product_name VARCHAR(1000),
    sub_category VARCHAR(100),
    positive_customer_exp NUMBER(10,2),
    sentence_count NUMBER(10),
    month STRING(15),
    year NUMBER(4),
    start_date DATE,
    end_date DATE
);

-- insert marketplace data into a newly created customer_exp_reviews table 
INSERT INTO CUSTOMER_EXP_REVIEWS
SELECT * 
FROM CUSTOMER_EXP.PUBLIC.TRIAL_PRODUCT_CUSTOMER_EXPERIENCE_VIEW;

SELECT COUNT(*) 
FROM CUSTOMER_EXP_REVIEWS;

SELECT *
FROM CUSTOMER_EXP_REVIEWS
LIMIT 5;

-- create a product table to store unique product names from the customer_exp_reviews table. Limit it to 10 products only for the sake of this demo.

CREATE OR REPLACE TABLE PRODUCT 
AS
SELECT DISTINCT product_name
FROM CUSTOMER_EXP_REVIEWS
LIMIT 10;

SELECT COUNT(*)
FROM PRODUCT;

SELECT * 
FROM PRODUCT;

-- create secret
CREATE OR REPLACE SECRET vino_open_ai_api
 TYPE = GENERIC_STRING
 SECRET_STRING = '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';

-- create network rule
CREATE OR REPLACE NETWORK RULE vino_apis_network_rule
 MODE = EGRESS
 TYPE = HOST_PORT
 VALUE_LIST = ('api.openai.com');

-- create external access integration
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION vino_external_access_int
 ALLOWED_NETWORK_RULES = (vino_apis_network_rule)
 ALLOWED_AUTHENTICATION_SECRETS = (vino_open_ai_api)
 ENABLED = true;

-- create snowpark python function v1 to invoke gpt3.5
 
CREATE OR REPLACE FUNCTION PROD_DESC_CHATGPT35_V1(query varchar)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = 3.9
HANDLER = 'complete_me'
EXTERNAL_ACCESS_INTEGRATIONS = (vino_external_access_int)
SECRETS = ('openai_key' = vino_open_ai_api)
PACKAGES = ('openai')
AS
$$
import _snowflake
import openai
openai.api_key = _snowflake.get_generic_secret_string('openai_key')
model="gpt-3.5-turbo"
prompt="Explain in details what the ingredients and capabilities of this cosmetic product are. Limit the response to 150 words only. Here is the product:"
def complete_me(QUERY):
    messages=[
    {'role': 'user', 'content':f"{prompt} {QUERY}"}
    ]
    response = openai.ChatCompletion.create(model=model,messages=messages,temperature=0)    
    return response.choices[0].message["content"]
$$;

SELECT PROD_DESC_CHATGPT35_V1('Magnesium Lotion With Aloe Vera, Shea Butter, Coconut Oil & Magnesium Oil For Muscle Pain & Leg Cramps – Rich In Magnesium Chloride And Vitamin E Oil') as response;

SELECT PROD_DESC_CHATGPT35_V1('Tandoori Mixed Grill') as response;

-- create snowpark python function v2 to invoke gpt3.5
 
CREATE OR REPLACE FUNCTION PROD_DESC_CHATGPT35_V2(query varchar)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = 3.9
HANDLER = 'complete_me'
EXTERNAL_ACCESS_INTEGRATIONS = (vino_external_access_int)
SECRETS = ('openai_key' = vino_open_ai_api)
PACKAGES = ('openai')
AS
$$
import _snowflake
import openai

openai.api_key = _snowflake.get_generic_secret_string('openai_key')
model="gpt-3.5-turbo"
prompt="Explain in detail what the ingredients and capabilities of this cosmetic product are. Limit the response to 150 words only. Respond with OOPS!! it is not a beauty product if the product in question is not a cosmetic or a beauty product. Here is the product:"

def complete_me(QUERY):
    messages=[
    {'role': 'user', 'content':f"{prompt} {QUERY}"}
    ]
    response = openai.ChatCompletion.create(model=model,messages=messages,temperature=0)    
    return response.choices[0].message["content"]
$$;

SELECT PROD_DESC_CHATGPT35_V2('Magnesium Lotion With Aloe Vera, Shea Butter, Coconut Oil & Magnesium Oil For Muscle Pain & Leg Cramps – Rich In Magnesium Chloride And Vitamin E Oil') as response;

SELECT PROD_DESC_CHATGPT35_V2('Tandoori Mixed Grill') as response;

-- comparing the gpt-3.5 responses from prompt engineering

CREATE OR REPLACE TABLE PRODUCT_DESC
AS
SELECT product_name, 
    PROD_DESC_CHATGPT35_V1(product_name) as DESC_V1,
    PROD_DESC_CHATGPT35_V2(product_name) as DESC_V2
FROM PRODUCT;

SELECT * 
FROM PRODUCT_DESC;

-- create snowpark python function v1 to invoke gpt4

CREATE OR REPLACE FUNCTION PROD_DESC_CHATGPT4_V1(query varchar)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = 3.9
HANDLER = 'complete_me'
EXTERNAL_ACCESS_INTEGRATIONS = (vino_external_access_int)
SECRETS = ('openai_key' = vino_open_ai_api)
PACKAGES = ('openai')
AS
$$
import _snowflake
import openai
def complete_me(QUERY):
    openai.api_key = _snowflake.get_generic_secret_string('openai_key')
    messages = [{"role": "system", "content": "Explain in details what the ingredients and capabilities of this cosmetic product are. Limit the response to 150 words only. Here is the product: "}, {"role": "user", "content": QUERY}]
    model="gpt-4"
    response = openai.ChatCompletion.create(model=model,messages=messages,temperature=0,)    
    return response.choices[0].message["content"]
$$;

SELECT PROD_DESC_CHATGPT4_V1('Magnesium Lotion With Aloe Vera, Shea Butter, Coconut Oil & Magnesium Oil For Muscle Pain & Leg Cramps – Rich In Magnesium Chloride And Vitamin E Oil') as response;

SELECT PROD_DESC_CHATGPT4_V1('Tandoori Mixed Grill') as response;

-- create snowpark python function v2 to invoke gpt4

CREATE OR REPLACE FUNCTION PROD_DESC_CHATGPT4_V2(query varchar)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = 3.9
HANDLER = 'complete_me'
EXTERNAL_ACCESS_INTEGRATIONS = (vino_external_access_int)
SECRETS = ('openai_key' = vino_open_ai_api)
PACKAGES = ('openai')
AS
$$
import _snowflake
import openai
def complete_me(QUERY):
    openai.api_key = _snowflake.get_generic_secret_string('openai_key')
    messages = [{"role": "system", "content": "You are an AI assistant who only knows about different cosmetic products and can explain in detail what the ingredients and capabilities of the product are. Limit the response to 150 words only. Here is the product: "}, {"role": "user", "content": QUERY}]
    model="gpt-4"
    response = openai.ChatCompletion.create(model=model,messages=messages,temperature=0,)    
    return response.choices[0].message["content"]
$$;

SELECT PROD_DESC_CHATGPT4_V2('Magnesium Lotion With Aloe Vera, Shea Butter, Coconut Oil & Magnesium Oil For Muscle Pain & Leg Cramps – Rich In Magnesium Chloride And Vitamin E Oil') as response;

SELECT PROD_DESC_CHATGPT4_V2('Tandoori Mixed Grill') as response;

-- comparing gpt4 responses from prompt engineering

CREATE OR REPLACE TABLE PRODUCT_DESC_GPT4
AS
SELECT product_name, 
    PROD_DESC_CHATGPT4_V1(product_name) as DESC_V1,
    PROD_DESC_CHATGPT4_V2(product_name) as DESC_V2
FROM PRODUCT;

SELECT * 
FROM PRODUCT_DESC_GPT4;

-- add a review column to the PRODUCT_DESC_GPT4 table
ALTER TABLE PRODUCT_DESC_GPT4 ADD REVIEW STRING(2);
