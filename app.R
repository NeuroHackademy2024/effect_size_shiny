# example from https://shiny.rstudio.com/tutorial/written-tutorial/lesson5/
# different ways of printing text: https://stackoverflow.com/questions/50781653/renderprint-option-in-shinyapp
# after adding shiny library, run with: runApp("app.R")
# install packages with R, not VSCode (VSC sometimes requires extra libraries)

# this is a change i made in the sim_ci branch



# list of packages required:
list.of.packages <- c("shiny", "ggplot2", "oro.nifti",
                      "neurobase", "ggcorrplot", "ggridges", "pheatmap",
                      "shinycssloaders", "shinyjs")

# checking missing packages from list
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]

# install missing packages ##TODO## UPDATE WHEN WE ADD MORE MAPS
if (length(new.packages)) install.packages(new.packages, dependencies = TRUE)

#load packages and data
library(shiny)
library(ggplot2)
library(oro.nifti)
library(neurobase)
library(ggcorrplot)
library(ggridges)
library(pheatmap)
library(shinycssloaders)
library(shinyjs)
d_clean <- readRDS("data/d_clean_whcp.rds")

# options for spinner
options(spinner.color="#9ecadb", spinner.color.background="#ffffff", spinner.size=1)

# list of available effect maps for visualization
effect_maps_available = c("emotion", "gambling", "relational", "social", "wm")

# User interface ----
ui <- fluidPage(
  useShinyjs(),

  titlePanel("Typical fMRI Effect Size Explorer"),
  
  hr(), # space

  fluidRow( # top row: inputs, probability density plots
      column(4, # inputs
      helpText("Select from the following options to visualize effect sizes:"),
                  
      selectInput("dataset",
      			  label = "Dataset",
      			  choices = c("All" = "*", "ABCD", "SLIM", "HCP" = "hcp", "PNC" = "pnc", "UKB" = "ukb", "HBN" = "hbn", "IMAGEN")),
      
      selectInput("measurement_type",
      			  label = "Measurement Type",
      			  choices = c("All" = "*", "Task-based Activation" = "act", "Functional Connectivity" = "fc")),
      
      selectInput("task",
      			  label = "Task",
      			  choices = c("All" = "*", "Rest" = "rest", "SST", "Emotion" = "emotion", "N-back" = "nback", "Relational" = "relational", "Social" = "social", "Working Memory" = "wm", "Gambling" = "gambling"),
              multiple = TRUE),
      
      selectInput("test_type",
      			  label = "Test Type",
      			  choices = c("All" = "*", "One-sample task-rest" = "\\.t\\.", "Two-sample group contrast" = "\\.t2\\.", "Behavioural correlation" = "\\.r\\.")), ## TODO: change this is d when data is updated to cohen's d
      			  
      conditionalPanel(
        condition = "input.test_type.indexOf('r') > -1",
            selectInput("behaviour",
      			  label = "Behavioural correlation",
      			  choices = c( "All" = "*","Age" = "\\.age", "IQ" = "\\.iq", "Fluid Intelligence" = "\\.gf", "Peabody Picture Vocab Test" = "\\.ppvt", "Expressive Vocab Test" = "\\.evt", "Stop Signal Task" = "\\.SST", "Letter N-Back Accuracy" = "\\.lnbxacc", "Letter N-Back Response Time" = "\\.lnbxrt", "Penn Face Memory Test Accuracy" = "\\.pfmtxacc", "Penn Face Memory Test Response Time" = "\\.pfmtxrt", "Penn Matrix Reasoning Test Correct Responses" = "\\.pmatxrc", "Penn Verbal Reasoning Test Accuracy" = "\\.pvrtxacc", "Penn Verbal Reasoning Test Response Time" = "\\.pvrtxrt", "Penn Word Memory Test Accuracy" = "\\.pwmtxacc", "Penn Word Memory Test Response Time" = "\\.pwmtxrt", "Wide Range Assessment Test" = "\\.wrat"),
              multiple = TRUE)),
      # selectInput("behaviour",
      # 			  label = "Behavioural correlation",
      # 			  choices = c( "All" = "*","Age" = "\\.age", "IQ" = "\\.iq", "Fluid Intelligence" = "\\.gf", "Peabody Picture Vocab Test" = "\\.ppvt", "Expressive Vocab Test" = "\\.evt", "Stop Signal Task" = "\\.SST", "Letter N-Back Accuracy" = "\\.lnbxacc", "Letter N-Back Response Time" = "\\.lnbxrt", "Penn Face Memory Test Accuracy" = "\\.pfmtxacc", "Penn Face Memory Test Response Time" = "\\.pfmtxrt", "Penn Matrix Reasoning Test Correct Responses" = "\\.pmatxrc", "Penn Verbal Reasoning Test Accuracy" = "\\.pvrtxacc", "Penn Verbal Reasoning Test Response Time" = "\\.pvrtxrt", "Penn Word Memory Test Accuracy" = "\\.pwmtxacc", "Penn Word Memory Test Response Time" = "\\.pwmtxrt", "Wide Range Assessment Test" = "\\.wrat"),
      #         multiple = TRUE), 

      selectInput("spatial_scale",
              label = "Spatial scale",
              choices = c("Univariate", "Network-level", "whole-brain")),
              
      selectInput("group_by", 
                  label = "What do you want to group by?",
                  choices = c("None", "Statistic", "Phenotype Category"))
    
      ),

      column(8, align = "center", # probability density plots
      h2("Effect size probability density"),
      withSpinner(plotOutput("histograms"), type = 1)
      )
      ),

hr() ,
helpText("To visualize an FC effect size matrix, select FC as Measurement Type, and complete other selections."),
helpText("To visualize activation effect sizes on the brain, select Task-Based Activation and select a dataset, task, and test type."),

    fluidRow( # second row: conditional row of additional inputs and plots depending on previous selections
        column(4, # if activation maps are selected, show MRI visualization inputs
        conditionalPanel(
        condition = "input.measurement_type === 'act' && input.dataset !== '*' && input.task !== '*' && input.test_type !== '*' && input.behaviour !== '*'",
        sidebarPanel(
            numericInput("xCoord", "X Coordinate", 30),
            numericInput("yCoord", "Y Coordinate", 30),
            numericInput("zCoord", "Z Coordinate", 30))
    )),

        column(8, align = "center", # if FC is selected, show heatplot of FC effect sizes
        conditionalPanel(
          condition = "input.measurement_type === 'fc' && input.dataset !== '*' && input.task !== '*' && input.test_type !== '*' && input.behaviour !== '*' && input.behaviour.length > 0",
          h2("Effect size matrix"),
          withSpinner(plotOutput("maps"), type = 1)
          ),
        conditionalPanel( # if activation maps selected, show MRI visualization
          condition = "input.measurement_type === 'act' && input.dataset !== '*' && input.task !== '*' && input.test_type !== '*'",
          h2("Effect size maps"),
          withSpinner(plotOutput("brain"), type = 1)
          ))
    )
  )


# Server logic ----
server <- function(input, output, session) {
    # set reactive parameters
    v <- reactiveValues()
    observe({
        # change the data being used to generate plots depending on inputs selected
      v$d_clean <- subset(d_clean, grepl(input$dataset, d_clean$study) & 
      							   grepl(input$measurement_type, d_clean$study) &
      							   # grepl(input$task, d_clean$study) &
                       (d_clean$study %in% input$task | grepl(paste(input$task, collapse="|"), d_clean$study, ignore.case = TRUE)) &
      							   grepl(input$test_type, d_clean$study) &
      							   (d_clean$study %in% input$behaviour | grepl(paste(input$behaviour, collapse="|"), d_clean$study, ignore.case = TRUE)))
      
      if (!is.null(input$task) && length(input$task) == 1 && input$task != "*" && input$task %in% effect_maps_available) {
        file_list <- list.files(path = "/Users/halleeshearer/Library/CloudStorage/GoogleDrive-halleeninet@gmail.com/.shortcut-targets-by-id/17uYR-Ubbo9n0459awrNyRct0CL4MwAXl/Hallee-Steph share/visualize_effects_app/data/", full.names = TRUE)
        v$case_task <- toupper(input$task)
        pattern <- paste0(v$case_task, ".*\\.nii\\.gz")
        matching_file <- grep(pattern, file_list, value = TRUE)
        v$effect_map <- readnii(matching_file)
      }

      v$this_fill <- "statistic"

      if (input$group_by == "None") { # show each individual study
        v$grouping <- "study"
        v$axis_label <- "Study"
        v$this_density_scale <- 5
        v$this_xlim <- c(-.5,.5)
      }
      else if(input$group_by == "Statistic") { # group by statistic
        v$grouping <- "statistic"
        v$axis_label <- "Statistic"
        v$this_density_scale <- 2.1
        v$this_xlim <- c(-1,1)
      }
      else if (input$group_by == "Phenotype Category") { # group by phenotype category
        v$grouping <- "code"
        #v$this_fill <- "code"
        v$axis_label <- "Phenotype Category"
        v$this_density_scale <- 3
        v$this_xlim <- c(-0.5, 0.5)
      }

      # reset behavioural correlation selections when test_type is changed from behavioural correlation to something else
      # the behavioural correlation selectInput disappears when test_type is not behavioural correlation, 
      # so need to reset when it disappears
      observeEvent(input$test_type, {
        if (input$test_type != "\\.r\\.") {
        updateSelectInput(session, "behaviour", selected = "*")}}, ignoreNULL = TRUE)
    })
      


    # plot
    # render UI
    output$histograms <- renderPlot({
      # d_clean %>% filter(statistic == "r") # TODO: filter by input categories or compare all
      ggplot(v$d_clean,  aes(x = d, y = .data[[v$grouping]], fill = .data[[v$this_fill]])) +
        geom_density_ridges(scale = v$this_density_scale) +
        theme_ridges() +
        #theme(legend.position = "none") +
        labs(y = v$axis_label, x = "Cohen's d") +
        theme(axis.title.y = element_text(size = 20, face = "bold", hjust = 0.5),
        	  axis.title.x = element_text(size = 20, face = "bold", hjust = 0.5)) +
        xlim(v$this_xlim) +
        scale_fill_manual(values = c("t" = '#AABBE9', "r" = "#EBC6D0", "t2" = "#BEDCD5", "t (act)" = "#ECE7BC"))
    })
 

    # output$maps <- renderPlot({
    #     t <- v$d_clean[[1]]
    #     n_nodes <- ((-1 + sqrt(1 + 8 * length(t))) / 2) + 1
    #     trilmask <- lower.tri(matrix(1, nrow = n_nodes, ncol = n_nodes))
    #     t2 <- trilmask
    #     t2[trilmask] <- t
    #     image(100 * t(apply(t2, 2, rev)),
    #           xlab = sprintf("%s Nodes", n_nodes),
    #           ylab = sprintf("%s Nodes", n_nodes),
    #           axes = FALSE)
    #     axis(1, at = seq(0, n_nodes, by = 20), labels = seq(0, n_nodes, by = 20))  # Customize X-axis
    #     axis(2, at = seq(0, n_nodes, by = 20), labels = seq(0, n_nodes, by = 20))  # Customize Y-axis
    #     })

    # try plotting the map with heatmap instead of image
    output$maps <- renderPlot({
      validate(need(length(input$task) < 2, "Please only select one task."),
      need(length(input$behaviour) > 0, "Please select one behavioural correlation."),
      need(length(input$behaviour) < 2, "Please only select one behavioural correlation."),
      need(dim(v$d_clean)[1] > 0, "We do not have data for the selected parameters"))
        t <- v$d_clean[[1]]
        n_nodes <- ((-1 + sqrt(1 + 8 * length(t))) / 2) + 1
        trilmask <- lower.tri(matrix(1, nrow = n_nodes, ncol = n_nodes))
        t2 <- trilmask
        t2[trilmask] <- t
        xlabel <- sprintf("%s Nodes", n_nodes)
        ylabel <- sprintf("%s Nodes", n_nodes)

        heatmap(t(apply(t2, 2, rev)),
          Colv = NA, Rowv = NA,  # Turn off row and column clustering
          col = heat.colors(256),
          xlab = xlabel, ylab = ylabel,
          scale = "none"
        )
    })

    # try plotting brain images:
    ## TODO ## currently we only have one-sample task-act maps, will need to tweak this code when we get other test types
    output$brain <- renderPlot({
        # load template brain image: ** TODO WILL NEED TO CHANGE **
    template <- readnii('/Users/halleeshearer/Desktop/visualize_effects_app/data/anatomical.nii')
      validate(
      need(length(input$task) < 2, "Please only select one task."),
      #need(dim(v$d_clean)[1] > 0, "We do not have data for the selected parameters"),
      need(input$test_type == "\\.t\\.", "We currently only have task-based activation maps for one-sample task-rest contrasts")
    )
    # load sample stat map: ** WILL NEED TO CHANGE **
    # effect_map <- readnii('/Users/halleeshearer/Desktop/visualize_effects_app/data/abstract_association-test_z_FDR_0.01.nii')
  
        ortho2(
            x = template,
            y = v$effect_map,
            crosshairs = FALSE,
            bg = 'black',
            NA.x = TRUE,
            col.y = oro.nifti::hotmetal(),
            xyz = c(input$xCoord, input$yCoord, input$zCoord),
            ycolorbar = TRUE,
            ybreaks = seq(min(v$effect_map), max(v$effect_map), length.out = 65),
            mfrow = c(1, 3),
        )


        # orthographic(template, effect_map,
        # xyz = c(input$xCoord, input$yCoord, input$zCoord),
        # bg = 'white', col = "white")
    })
}


# Run app ----
shinyApp(ui, server)