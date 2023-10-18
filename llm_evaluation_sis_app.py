# Import libraries
import streamlit as st
from snowflake.snowpark.context import get_active_session
import snowflake.snowpark.functions as F

# Write directly to the app
st.title("LLM Evaluation using Human Feedback")
st.write(
    """
    Read the different versions of the product description in `Desc A` and `Desc B`. \n
    If `Desc A` is better, enter `A` in Review column. \n
    If `Desc B` is better, enter `B` in Review column. \n
    If both of them are equally good, enter `AB` in Review column. \n
    If none of the descriptions are good, enter `NA` in Review column. \n    
    """
)
session = get_active_session()

session.sql("USE DATABASE CUSTOMER_EXP_DB")
session.sql("USE SCHEMA CUSTOMER_EXP_SCHEMA")
session.sql("USE WAREHOUSE VINO_CUSTOMER_EXP_WH_M")

# Evaluating GPT4 responses
df = session.table("PRODUCT_DESC_GPT4")
df = df.with_column('REVIEW', F.lit(' '))

desc_gpt4 = session.create_dataframe(st.experimental_data_editor(df))

# Button to submit reviews
if st.button("Save GPT4 Reviews"):
    desc_gpt4.write.mode("append").save_as_table("PRODUCT_DESC_GPT4")
    st.snow()



